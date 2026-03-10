defmodule MathViz.Engines.SymPyWorker do
  @moduledoc "Long-lived Port wrapper around the Python SymPy runner."

  use GenServer

  alias MathViz.Contracts
  alias MathViz.Contracts.SymPyRequest

  @default_name __MODULE__

  defstruct port: nil,
            buffer: "",
            pending: %{},
            python_executable: nil,
            script_path: nil,
            port_error: nil

  @type state :: %__MODULE__{
          port: port() | nil,
          buffer: String.t(),
          pending: %{optional(String.t()) => GenServer.from()},
          python_executable: String.t(),
          script_path: String.t(),
          port_error: term()
        }

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, @default_name)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @spec execute(String.t(), keyword()) ::
          {:ok, MathViz.Contracts.SymPyResponse.t()} | {:error, term()}
  def execute(sympy_executable, opts \\ []) when is_binary(sympy_executable) do
    server = Keyword.get(opts, :server, @default_name)
    request_id = Integer.to_string(System.unique_integer([:positive]))
    request = Contracts.new_sympy_request(request_id, sympy_executable)
    timeout = Keyword.get(opts, :timeout, 5_000)

    try do
      GenServer.call(server, {:execute, request}, timeout)
    catch
      :exit, {:timeout, _} -> {:error, :timeout}
      :exit, reason -> {:error, {:sympy_call_failed, reason}}
    end
  end

  @impl true
  def init(opts) do
    python_executable = Keyword.get(opts, :python_executable, preferred_python_executable())

    script_path =
      Keyword.get(
        opts,
        :script_path,
        Path.expand("../../../priv/python/sympy_runner.py", __DIR__)
      )

    {:ok,
     %__MODULE__{
       python_executable: python_executable,
       script_path: script_path
     }, {:continue, :open_port}}
  end

  @impl true
  def handle_continue(:open_port, state) do
    {:noreply, open_port(state)}
  end

  @impl true
  def handle_call({:execute, %SymPyRequest{}}, _from, %{port: nil, port_error: reason} = state) do
    {:reply, {:error, {:sympy_unavailable, reason}}, state}
  end

  def handle_call({:execute, %SymPyRequest{} = request}, from, %{port: port} = state) do
    payload = Jason.encode!(request) <> "\n"
    true = Port.command(port, payload)

    {:noreply, %{state | pending: Map.put(state.pending, request.request_id, from)}}
  end

  @impl true
  def handle_info({port, {:data, data}}, %{port: port} = state) do
    {lines, rest} = split_lines(state.buffer <> data)

    next_state =
      Enum.reduce(lines, %{state | buffer: rest}, fn line, acc ->
        handle_response_line(line, acc)
      end)

    {:noreply, next_state}
  end

  def handle_info({port, {:exit_status, status}}, %{port: port} = state) do
    Enum.each(state.pending, fn {_request_id, from} ->
      GenServer.reply(from, {:error, {:sympy_port_exited, status}})
    end)

    {:noreply,
     %{
       state
       | port: nil,
         pending: %{},
         buffer: "",
         port_error: {:sympy_port_exited, status}
     }, {:continue, :open_port}}
  end

  def handle_info(_message, state), do: {:noreply, state}

  defp open_port(state) do
    try do
      port =
        Port.open({:spawn_executable, String.to_charlist(state.python_executable)}, [
          :binary,
          :exit_status,
          {:args, ["-u", state.script_path]}
        ])

      %{state | port: port, port_error: nil}
    rescue
      error ->
        %{state | port: nil, port_error: Exception.message(error)}
    end
  end

  defp split_lines(buffer) do
    segments = String.split(buffer, "\n")
    {Enum.drop(segments, -1), List.last(segments) || ""}
  end

  defp handle_response_line("", state), do: state

  defp handle_response_line(line, state) do
    with {:ok, decoded} <- Jason.decode(line),
         {:ok, response} <- Contracts.parse_sympy_response(decoded),
         from when not is_nil(from) <- Map.get(state.pending, response.request_id) do
      reply =
        if response.ok do
          {:ok, response}
        else
          {:error, {:sympy_execution_failed, response.error}}
        end

      GenServer.reply(from, reply)
      %{state | pending: Map.delete(state.pending, response.request_id)}
    else
      _ ->
        state
    end
  end

  defp preferred_python_executable do
    venv_python = Path.expand("../../../.venv/bin/python", __DIR__)

    cond do
      File.exists?(venv_python) -> venv_python
      executable = System.find_executable("python3") -> executable
      true -> "python3"
    end
  end
end
