defmodule MathVizWeb.MathOrchestratorLive do
  use MathVizWeb, :live_view

  alias MathViz.API.VisionInput
  alias MathViz.Solve

  @graph_engines [:desmos, :geogebra]

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> allow_upload(:vision_input,
        accept: ~w(.jpg .jpeg .png .webp),
        auto_upload: true,
        max_entries: 1,
        max_file_size: VisionInput.max_size()
      )
      |> assign(default_assigns())

    {:ok, socket}
  end

  @impl true
  def handle_event("solve", %{"prompt" => %{"input_query" => raw_query}}, socket) do
    query = String.trim(raw_query)
    has_upload? = socket.assigns.uploads.vision_input.entries != []
    upload_error = upload_error_message(socket.assigns.uploads.vision_input)

    cond do
      upload_error ->
        {:noreply, put_flash(socket, :error, upload_error)}

      query == "" and not has_upload? ->
        {:noreply, put_flash(socket, :error, "Enter a math prompt or attach an image to start.")}

      true ->
        vision = consume_vision_input(socket)
        request_id = socket.assigns.request_id + 1
        parent = self()

        task =
          Task.Supervisor.async_nolink(MathViz.TaskSupervisor, fn ->
            Solve.run(%{"query" => raw_query, "vision" => vision},
              notify: fn stage, payload ->
                send(parent, {:pipeline_stage, request_id, stage, payload})
              end
            )
          end)

        {:noreply,
         socket
         |> clear_flash()
         |> assign(reset_assigns(raw_query, request_id, task.ref))}
    end
  end

  def handle_event("validate_upload", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("set_graph_engine", %{"engine" => engine_name}, socket) do
    engine = normalize_graph_engine(engine_name)

    socket =
      if engine in @graph_engines do
        assign(socket, active_graph_engine: engine)
      else
        socket
      end

    {:noreply, maybe_push_graph_events(socket)}
  end

  @impl true
  def handle_info({:pipeline_stage, request_id, :computing, _payload}, socket) do
    {:noreply, maybe_assign_status(socket, request_id, :computing)}
  end

  def handle_info({:pipeline_stage, request_id, :verifying, payload}, socket) do
    socket =
      socket
      |> maybe_assign_status(request_id, :verifying)
      |> maybe_assign_symbol_preview(request_id, payload)

    {:noreply, socket}
  end

  def handle_info({:pipeline_stage, request_id, :rendering, _payload}, socket) do
    {:noreply, maybe_assign_status(socket, request_id, :rendering)}
  end

  def handle_info({:pipeline_stage, request_id, :complete, _payload}, socket) do
    {:noreply, maybe_assign_status(socket, request_id, socket.assigns.status)}
  end

  def handle_info({ref, {:ok, response}}, %{assigns: %{current_task_ref: ref}} = socket) do
    Process.demonitor(ref, [:flush])

    {:noreply,
     socket
     |> assign(current_task_ref: nil)
     |> assign(response_assigns(response))
     |> maybe_push_graph_events()}
  end

  def handle_info({ref, {:error, reason}}, %{assigns: %{current_task_ref: ref}} = socket) do
    Process.demonitor(ref, [:flush])

    {:noreply,
     socket
     |> assign(current_task_ref: nil, status: :error, error_message: format_error(reason))
     |> put_flash(:error, "The pipeline could not complete.")}
  end

  def handle_info(
        {:DOWN, ref, :process, _pid, reason},
        %{assigns: %{current_task_ref: ref}} = socket
      ) do
    {:noreply,
     socket
     |> assign(current_task_ref: nil, status: :error, error_message: inspect(reason))
     |> put_flash(:error, "The pipeline crashed before returning a result.")}
  end

  def handle_info(_message, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <main class="min-h-screen bg-white text-stone-950">
        <section
          class="mx-auto flex min-h-screen max-w-3xl flex-col px-4 sm:px-6 lg:px-0"
          phx-drop-target={@uploads.vision_input.ref}
        >
          <header class="flex items-center justify-between py-4">
            <p class="text-[0.65rem] font-semibold uppercase tracking-[0.32em] text-stone-500">
              MathViz
            </p>

            <details class="relative text-xs text-stone-500">
              <summary class="cursor-pointer list-none rounded-full border border-stone-200 px-3 py-1.5 font-medium text-stone-700 marker:hidden">
                Engine
              </summary>

              <div class="absolute right-0 mt-3 w-[18rem] rounded-2xl border border-stone-200 bg-white p-4 shadow-lg shadow-stone-900/5">
                <div class="space-y-3">
                  <div class="flex items-center justify-between">
                    <span class="uppercase tracking-[0.22em] text-stone-400">Adapter</span>
                    <span class="font-mono text-stone-700">
                      {String.upcase(to_string(@adapter || :stub))}
                    </span>
                  </div>

                  <div class="grid grid-cols-2 gap-3">
                    <div class="rounded-xl bg-stone-50 p-3">
                      <p class="uppercase tracking-[0.2em] text-stone-400">N -> S</p>
                      <p class="mt-1 font-mono text-stone-700">{Map.get(@timings, :nlp_ms, 0)} ms</p>
                    </div>
                    <div class="rounded-xl bg-stone-50 p-3">
                      <p class="uppercase tracking-[0.2em] text-stone-400">SymPy</p>
                      <p class="mt-1 font-mono text-stone-700">
                        {Map.get(@timings, :sympy_ms, 0)} ms
                      </p>
                    </div>
                    <div class="rounded-xl bg-stone-50 p-3">
                      <p class="uppercase tracking-[0.2em] text-stone-400">S -> L</p>
                      <p class="mt-1 font-mono text-stone-700">
                        {Map.get(@timings, :verify_ms, 0)} ms
                      </p>
                    </div>
                    <div class="rounded-xl bg-stone-50 p-3">
                      <p class="uppercase tracking-[0.2em] text-stone-400">S -> G</p>
                      <p class="mt-1 font-mono text-stone-700">
                        {Map.get(@timings, :graph_ms, 0)} ms
                      </p>
                    </div>
                  </div>

                  <div :if={@lean_proof_state} class="rounded-xl border border-stone-200 p-3">
                    <p class="uppercase tracking-[0.2em] text-stone-400">Proof</p>
                    <p class="mt-2 font-mono text-stone-700">{@lean_proof_state}</p>
                  </div>

                  <p :if={@error_message} class="text-rose-700">{@error_message}</p>
                </div>
              </div>
            </details>
          </header>

          <div class="flex-1 pb-40 pt-6">
            <div class="space-y-12 sm:space-y-14">
              <section :if={has_output?(@sympy_ast, @chat_reply, @error_message)} class="space-y-5">
                <div class="flex items-center gap-3">
                  <span
                    class={status_dot_classes(@status, @is_verified, @chat_reply, @error_message)}
                    data-testid="status-indicator"
                  >
                  </span>
                  <span data-testid="status-label" data-status={@status} class="sr-only">
                    {format_status(@status)}
                  </span>
                </div>

                <div
                  :if={@chat_reply}
                  class="space-y-4 rounded-[2rem] border border-stone-200 bg-stone-50/70 p-6"
                  data-testid="chat-output"
                >
                  <div class="space-y-2">
                    <p class="text-[0.65rem] font-semibold uppercase tracking-[0.28em] text-stone-400">
                      Theory
                    </p>
                    <p class="font-serif text-2xl leading-tight text-stone-950">
                      {@input_query}
                    </p>
                  </div>

                  <div class="border-l border-stone-200 pl-4">
                    <p class="whitespace-pre-line text-base leading-7 text-stone-700">
                      {@chat_reply}
                    </p>

                    <ul
                      :if={@chat_notes != []}
                      class="mt-4 space-y-2 text-sm leading-6 text-stone-500"
                    >
                      <%= for note <- @chat_notes do %>
                        <li>{note}</li>
                      <% end %>
                    </ul>
                  </div>
                </div>

                <div :if={@sympy_ast} class="space-y-4">
                  <div
                    id="katex-output"
                    phx-hook="MathRender"
                    phx-update="ignore"
                    data-testid="katex-output"
                    data-latex={@output_latex}
                    class="min-h-0 py-1"
                  >
                  </div>

                  <div class="border-l border-stone-200 pl-4">
                    <p class="font-serif text-2xl leading-tight text-stone-950">
                      {@sympy_ast.statement}
                    </p>
                    <p class="mt-3 font-mono text-sm text-stone-600">{@sympy_ast.expression}</p>

                    <ul
                      :if={@sympy_ast.notes != []}
                      class="mt-4 space-y-2 text-sm leading-6 text-stone-500"
                    >
                      <%= for note <- @sympy_ast.notes do %>
                        <li>{note}</li>
                      <% end %>
                    </ul>
                  </div>
                </div>

                <p :if={@error_message} class="text-sm leading-6 text-rose-700">
                  {@error_message}
                </p>
              </section>

              <section :if={has_proof?(@lean_proof_state)} class="space-y-3">
                <div class="flex items-center justify-between gap-4">
                  <p class="text-[0.65rem] font-semibold uppercase tracking-[0.28em] text-stone-400">
                    Proof
                  </p>
                  <span class="font-mono text-[0.7rem] uppercase tracking-[0.24em] text-stone-400">
                    {@lean_proof_state}
                  </span>
                </div>

                <pre
                  class="overflow-x-auto border-l border-stone-200 pl-4 font-mono text-xs leading-7 text-stone-600"
                  data-testid="proof-state"
                ><%= @proof_summary %></pre>
              </section>

              <section :if={has_graph?(@graph_config)} class="space-y-4">
                <div class="flex items-center justify-between gap-4">
                  <div
                    class="inline-flex items-center rounded-full border border-stone-200 bg-stone-50 p-1"
                    data-testid="graph-tabs"
                  >
                    <%= for engine <- available_graph_engines(@graph_config) do %>
                      <button
                        type="button"
                        phx-click="set_graph_engine"
                        phx-value-engine={engine}
                        class={[
                          "rounded-full px-3 py-1.5 text-sm font-medium transition-colors",
                          @active_graph_engine == engine && "bg-white text-stone-950 shadow-sm",
                          @active_graph_engine != engine && "text-stone-500 hover:text-stone-900"
                        ]}
                        data-testid={"graph-tab-#{engine}"}
                      >
                        {graph_engine_label(engine)}
                      </button>
                    <% end %>
                  </div>

                  <span class="text-[0.65rem] uppercase tracking-[0.28em] text-stone-400">
                    {graph_engine_label(@active_graph_engine)}
                  </span>
                </div>

                <div class="-mx-4 overflow-hidden sm:mx-0">
                  <div
                    :if={
                      @active_graph_engine == :desmos and has_graph_payload?(@graph_config, :desmos)
                    }
                    id="desmos-surface"
                    phx-hook="DesmosHook"
                    phx-update="ignore"
                    data-testid="desmos-surface"
                    data-config={@desmos_json}
                    class="h-[60vh] min-h-[22rem] w-full overflow-hidden rounded-none border-y border-stone-200 bg-stone-50 sm:rounded-2xl sm:border"
                  >
                  </div>

                  <div
                    :if={
                      @active_graph_engine == :geogebra and
                        has_graph_payload?(@graph_config, :geogebra)
                    }
                    id="geogebra-surface"
                    phx-hook="GeoGebraHook"
                    phx-update="ignore"
                    data-testid="geogebra-surface"
                    data-config={@geogebra_json}
                    class="h-[60vh] min-h-[22rem] w-full overflow-hidden rounded-none border-y border-stone-200 bg-stone-50 sm:rounded-2xl sm:border"
                  >
                  </div>
                </div>
              </section>
            </div>
          </div>

          <div class="sticky bottom-0 z-30 mt-auto pb-[max(env(safe-area-inset-bottom),1rem)]">
            <div class="-mx-4 bg-white/90 px-4 pt-4 backdrop-blur sm:mx-0 sm:bg-transparent sm:px-0">
              <.form
                for={@form}
                id="solve-form"
                phx-submit="solve"
                phx-change="validate_upload"
                phx-hook="VisionDropzoneHook"
                class="mx-auto max-w-2xl rounded-[1.5rem] border border-stone-200 bg-white/95 p-3 shadow-lg shadow-stone-900/5 transition-colors"
              >
                <div class="flex items-end gap-2">
                  <label
                    for="vision-upload"
                    class="inline-flex h-10 w-10 shrink-0 cursor-pointer items-center justify-center rounded-full border border-stone-200 text-stone-500 transition hover:border-stone-300 hover:text-stone-900"
                    data-testid="vision-upload-trigger"
                    aria-label="Upload image"
                  >
                    <.icon name="hero-paper-clip" class="size-4" />
                  </label>

                  <.live_file_input
                    upload={@uploads.vision_input}
                    id="vision-upload"
                    class="hidden"
                    data-testid="vision-upload"
                  />

                  <textarea
                    id={@form[:input_query].id}
                    name={@form[:input_query].name}
                    rows="1"
                    class="min-h-[120px] w-full resize-none border-0 bg-transparent px-1 py-2 text-base text-stone-900 outline-none ring-0 placeholder:text-stone-400 focus:outline-none focus:ring-0"
                    placeholder="Enter an equation or natural language query..."
                    data-testid="query-input"
                  ><%= @form[:input_query].value %></textarea>
                </div>

                <div class="mt-3 flex items-center justify-end gap-3">
                  <button
                    type="submit"
                    class="inline-flex items-center rounded-full border border-stone-900 bg-stone-900 px-4 py-2 text-sm font-medium text-white transition-colors hover:bg-stone-800"
                    phx-disable-with="Sending..."
                    data-testid="submit-query"
                  >
                    Submit
                  </button>
                </div>

                <p
                  class="mt-2 text-center text-xs text-stone-400"
                  data-testid="vision-file-label"
                >
                  {vision_label(@uploads.vision_input)}
                </p>
              </.form>
            </div>
          </div>
        </section>
      </main>
    </Layouts.app>
    """
  end

  defp default_assigns do
    %{
      input_query: "",
      response_mode: nil,
      status: :idle,
      is_verified: false,
      sympy_ast: nil,
      chat_reply: nil,
      chat_notes: [],
      lean_proof_state: nil,
      proof_summary: "Verification has not started yet.",
      graph_config: %{},
      output_latex: "",
      error_message: nil,
      adapter: :stub,
      timings: %{},
      form: to_form(%{"input_query" => ""}, as: :prompt),
      request_id: 0,
      current_task_ref: nil,
      active_graph_engine: :desmos,
      desmos_json: "{}",
      geogebra_json: "{}"
    }
  end

  defp reset_assigns(query, request_id, task_ref) do
    default_assigns()
    |> Map.merge(%{
      input_query: query,
      status: :computing,
      request_id: request_id,
      current_task_ref: task_ref,
      proof_summary: "Preparing the natural-language morphism.",
      active_graph_engine: :desmos,
      form: to_form(%{"input_query" => query}, as: :prompt)
    })
  end

  defp response_assigns(response) do
    graph = response.graph || %{}
    symbol = response.symbol || %{}
    proof = response.proof || %{}
    response_mode = normalize_response_mode(response.mode)

    graph_config = %{
      desmos: Map.get(graph, :desmos, %{}),
      geogebra: Map.get(graph, :geogebra, %{})
    }

    %{
      response_mode: response_mode,
      status: response_status(response.status),
      is_verified: response.verified,
      sympy_ast:
        if(response_mode == :computation and symbol != %{},
          do: %{
            statement: Map.get(symbol, :statement),
            expression: Map.get(symbol, :expression),
            source: response.adapter,
            notes: Map.get(symbol, :notes, [])
          },
          else: nil
        ),
      chat_reply: response.chat_reply,
      chat_notes: response.chat_steps || [],
      lean_proof_state: if(response_mode == :computation, do: Map.get(proof, :state), else: nil),
      proof_summary:
        cond do
          response_mode == :chat -> "Theory response complete."
          true -> Map.get(proof, :summary)
        end,
      graph_config: graph_config,
      output_latex:
        if(response_mode == :computation,
          do: Map.get(graph, :latex_block) || Map.get(symbol, :latex, ""),
          else: ""
        ),
      error_message: response.error,
      adapter: response.adapter,
      timings: response.timings || %{},
      desmos_json: Jason.encode!(Map.get(graph_config, :desmos, %{})),
      geogebra_json: Jason.encode!(Map.get(graph_config, :geogebra, %{}))
    }
  end

  defp maybe_assign_status(socket, request_id, status)
       when request_id == socket.assigns.request_id do
    proof_summary =
      case status do
        :computing -> "Running the natural-language morphism into a symbolic state."
        :verifying -> "The verifier boundary is checking the symbolic claim."
        :rendering -> "Verification passed, building graph payloads."
        _ -> socket.assigns.proof_summary
      end

    assign(socket, status: status, proof_summary: proof_summary)
  end

  defp maybe_assign_status(socket, _request_id, _status), do: socket

  defp maybe_assign_symbol_preview(socket, request_id, %{symbol: expression})
       when request_id == socket.assigns.request_id do
    assign(socket,
      sympy_ast: %{
        statement: "Pending verification",
        expression: expression,
        source: socket.assigns.adapter,
        notes: []
      }
    )
  end

  defp maybe_assign_symbol_preview(socket, _request_id, _payload), do: socket

  defp maybe_push_graph_events(%{assigns: %{is_verified: false}} = socket), do: socket

  defp maybe_push_graph_events(socket) do
    socket
    |> maybe_push_graph_event(
      "update_graph",
      Map.get(socket.assigns.graph_config, :desmos, %{}),
      :desmos
    )
    |> maybe_push_graph_event(
      "geogebra:update",
      Map.get(socket.assigns.graph_config, :geogebra, %{}),
      :geogebra
    )
  end

  defp maybe_push_graph_event(socket, _event_name, %{}, _engine), do: socket

  defp maybe_push_graph_event(socket, event_name, payload, :desmos) do
    push_event(socket, event_name, payload)
  end

  defp maybe_push_graph_event(socket, event_name, payload, :geogebra) do
    push_event(socket, event_name, %{graph: payload})
  end

  defp consume_vision_input(socket) do
    socket
    |> consume_uploaded_entries(:vision_input, fn %{path: path}, entry ->
      {:ok,
       %{
         bytes: File.read!(path),
         mime:
           entry.client_type || MIME.from_path(entry.client_name) || "application/octet-stream",
         filename: entry.client_name,
         size: entry.client_size
       }}
    end)
    |> List.first()
  end

  defp format_status(:idle), do: "Idle"
  defp format_status(:computing), do: "Computing"
  defp format_status(:verifying), do: "Verifying"
  defp format_status(:rendering), do: "Rendering"
  defp format_status(:complete), do: "Complete"
  defp format_status(:error), do: "Error"
  defp format_status(other), do: other |> to_string() |> String.capitalize()

  defp format_error(reason) when is_binary(reason), do: reason
  defp format_error(%Ecto.Changeset{} = changeset), do: upload_error_text(changeset)
  defp format_error(reason), do: inspect(reason)

  defp response_status(status) when is_binary(status) do
    case status do
      "idle" -> :idle
      "computing" -> :computing
      "verifying" -> :verifying
      "rendering" -> :rendering
      "complete" -> :complete
      "error" -> :error
      _ -> :error
    end
  end

  defp response_status(status) when is_atom(status), do: status

  defp normalize_graph_engine(engine) when is_binary(engine) do
    case engine do
      "desmos" -> :desmos
      "geogebra" -> :geogebra
      _ -> :unknown
    end
  end

  defp normalize_graph_engine(engine) when is_atom(engine), do: engine

  defp graph_engine_label(:desmos), do: "Desmos"
  defp graph_engine_label(:geogebra), do: "GeoGebra"
  defp graph_engine_label(other), do: other |> to_string() |> String.capitalize()

  defp normalize_response_mode(mode) when mode in [:chat, :computation], do: mode
  defp normalize_response_mode("chat"), do: :chat
  defp normalize_response_mode(_mode), do: :computation

  defp has_output?(sympy_ast, chat_reply, error_message),
    do: not is_nil(sympy_ast) or is_binary(chat_reply) or not is_nil(error_message)

  defp has_proof?(lean_proof_state), do: is_binary(lean_proof_state) and lean_proof_state != ""

  defp has_graph?(graph_config) when is_map(graph_config) do
    has_graph_payload?(graph_config, :desmos) or has_graph_payload?(graph_config, :geogebra)
  end

  defp has_graph_payload?(graph_config, engine) when is_map(graph_config) do
    graph_config
    |> Map.get(engine, %{})
    |> case do
      payload when is_map(payload) -> payload != %{}
      _ -> false
    end
  end

  defp available_graph_engines(graph_config) do
    Enum.filter(@graph_engines, &has_graph_payload?(graph_config, &1))
  end

  defp vision_label(upload) do
    cond do
      upload_error_message(upload) ->
        upload_error_message(upload)

      upload.entries != [] ->
        entry = List.first(upload.entries)
        "Selected image: #{entry.client_name}"

      true ->
        "Enter a query, or drag & drop textbook photos and whiteboard sketches (JPG/PNG/WebP, max 5MB)."
    end
  end

  defp upload_error_message(upload) do
    cond do
      error = upload_errors(upload) |> List.first() ->
        upload_error_text(error)

      entry = Enum.find(upload.entries, &(upload_errors(upload, &1) != [])) ->
        upload
        |> upload_errors(entry)
        |> List.first()
        |> upload_error_text()

      true ->
        nil
    end
  end

  defp upload_error_text(%Ecto.Changeset{} = changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {message, _opts} -> message end)
    |> Enum.reduce(nil, fn
      {_field, [message | _]}, nil -> message
      _, acc -> acc
    end) || "request is invalid"
  end

  defp upload_error_text(:too_large), do: "Images must be 5MB or smaller."
  defp upload_error_text(:not_accepted), do: "Only JPG, PNG, and WebP uploads are supported."
  defp upload_error_text(other) when is_binary(other), do: other
  defp upload_error_text(other), do: inspect(other)

  defp status_dot_classes(status, is_verified, chat_reply, error_message) do
    base = "inline-flex h-2.5 w-2.5 rounded-full"

    tone =
      cond do
        not is_nil(error_message) or status == :error -> "bg-rose-500"
        is_verified -> "bg-emerald-500"
        is_binary(chat_reply) and chat_reply != "" -> "bg-sky-500"
        status in [:computing, :verifying, :rendering] -> "animate-pulse bg-amber-400"
        true -> "bg-stone-300"
      end

    [base, tone]
  end
end
