defmodule MathVizWeb.MathOrchestratorLive do
  use MathVizWeb, :live_view

  alias MathViz.Pipeline

  @layers [:desmos, :geogebra, :wolfram_steps, :lean_proof]

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, default_assigns())}
  end

  @impl true
  def handle_event("solve", %{"prompt" => %{"input_query" => raw_query}}, socket) do
    query = String.trim(raw_query)

    if query == "" do
      {:noreply, put_flash(socket, :error, "Enter a math prompt to start the pipeline.")}
    else
      request_id = socket.assigns.request_id + 1
      parent = self()

      task =
        Task.Supervisor.async_nolink(MathViz.TaskSupervisor, fn ->
          Pipeline.run(query,
            notify: fn stage, payload ->
              send(parent, {:pipeline_stage, request_id, stage, payload})
            end
          )
        end)

      {:noreply,
       socket
       |> clear_flash()
       |> assign(reset_assigns(socket.assigns.layers, raw_query, request_id, task.ref))}
    end
  end

  def handle_event("toggle_layer", %{"layer" => layer_name}, socket) do
    layer = normalize_layer(layer_name)

    socket =
      if layer in @layers do
        update(socket, :layers, fn layers -> Map.update!(layers, layer, &(!&1)) end)
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

  def handle_info({ref, {:ok, result}}, %{assigns: %{current_task_ref: ref}} = socket) do
    Process.demonitor(ref, [:flush])

    {:noreply,
     socket
     |> assign(current_task_ref: nil)
     |> assign(result_assigns(result))
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
      <main class="min-h-screen bg-white text-stone-900">
        <section class="mx-auto max-w-3xl px-6 py-12 lg:px-0">
          <header class="sticky top-0 z-20 -mx-6 mb-12 border-b border-stone-200 bg-white/95 px-6 py-4 backdrop-blur lg:mx-0 lg:px-0">
            <div class="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
              <div class="space-y-1">
                <p class="text-[0.65rem] font-semibold uppercase tracking-[0.35em] text-stone-500">
                  Verified-first mathematics over LiveView
                </p>
                <p class="max-w-xl text-sm leading-6 text-stone-600">
                  The math should feel like a document. The engine should feel optional.
                </p>
              </div>

              <div class="flex items-start gap-4 sm:items-center">
                <div class="text-right">
                  <p class="text-[0.65rem] uppercase tracking-[0.28em] text-stone-400">Status</p>
                  <p
                    class="mt-1 font-mono text-sm uppercase tracking-[0.18em] text-stone-700"
                    data-testid="status-label"
                    data-status={@status}
                  >
                    {format_status(@status)}
                  </p>
                </div>

                <details class="group mt-0.5 text-sm text-stone-600">
                  <summary class="cursor-pointer list-none font-medium text-stone-900 marker:hidden">
                    Engine
                  </summary>
                  <div class="mt-4 w-full min-w-[18rem] border-l border-stone-200 pl-4">
                    <div class="grid gap-2 text-xs uppercase tracking-[0.2em] text-stone-500 sm:grid-cols-4">
                      <div>
                        <p>N -> S</p>
                        <p class="mt-1 text-base font-medium tracking-normal text-stone-900">
                          {Map.get(@timings, :nlp_ms, 0)} ms
                        </p>
                      </div>
                      <div>
                        <p>SymPy</p>
                        <p class="mt-1 text-base font-medium tracking-normal text-stone-900">
                          {Map.get(@timings, :sympy_ms, 0)} ms
                        </p>
                      </div>
                      <div>
                        <p>S -> L</p>
                        <p class="mt-1 text-base font-medium tracking-normal text-stone-900">
                          {Map.get(@timings, :verify_ms, 0)} ms
                        </p>
                      </div>
                      <div>
                        <p>S -> G</p>
                        <p class="mt-1 text-base font-medium tracking-normal text-stone-900">
                          {Map.get(@timings, :graph_ms, 0)} ms
                        </p>
                      </div>
                    </div>

                    <div class="mt-5 space-y-2" data-testid="layer-toggles">
                      <div class="flex items-center justify-between border-b border-stone-100 pb-2 text-xs uppercase tracking-[0.2em] text-stone-500">
                        <span>Adapter {String.upcase(to_string(@adapter || :stub))}</span>
                        <span>{if @is_verified, do: "verified", else: "blocked"}</span>
                      </div>

                      <%= for {layer, enabled?} <- @layers do %>
                        <button
                          type="button"
                          phx-click="toggle_layer"
                          phx-value-layer={layer}
                          class="flex w-full items-center justify-between py-2 text-left transition hover:text-stone-900"
                          data-testid={"toggle-#{layer}"}
                        >
                          <span>
                            <span class="block text-xs font-semibold uppercase tracking-[0.18em] text-stone-700">
                              {layer_label(layer)}
                            </span>
                            <span class="mt-1 block text-xs leading-5 text-stone-500">
                              {layer_description(layer)}
                            </span>
                          </span>
                          <span class="font-mono text-xs uppercase tracking-[0.18em] text-stone-500">
                            {if enabled?, do: "On", else: "Off"}
                          </span>
                        </button>
                      <% end %>
                    </div>
                  </div>
                </details>
              </div>
            </div>
          </header>

          <section class="mb-16">
            <p class="text-[0.65rem] font-semibold uppercase tracking-[0.35em] text-stone-500">
              Natural language input
            </p>
            <h1 class="mt-3 font-serif text-5xl leading-[1.02] tracking-tight text-balance text-stone-900 sm:text-6xl">
              One prompt, one formal gate, three synchronized layers.
            </h1>
            <p class="mt-5 max-w-2xl text-base leading-8 text-stone-600">
              Phoenix coordinates the natural-language morphism, the verifier boundary, and the graph payloads. The user should mostly see beautiful math, not the machinery.
            </p>

            <.form for={@form} id="solve-form" phx-submit="solve" class="mt-10">
              <.input
                field={@form[:input_query]}
                type="textarea"
                label="Prompt"
                rows="4"
                class="w-full border-0 border-b border-stone-300 bg-transparent px-0 pb-4 pt-0 font-serif text-2xl leading-10 text-stone-900 shadow-none outline-none ring-0 placeholder:text-stone-400 focus:border-stone-900 focus:ring-0"
                placeholder="Prove the derivative of sin(x), then show the verified graph."
                data-testid="query-input"
              />
              <div class="mt-5 flex flex-wrap items-center gap-4">
                <button
                  type="submit"
                  class="font-mono text-xs font-semibold uppercase tracking-[0.28em] text-stone-900 transition hover:text-stone-600"
                  phx-disable-with="Translating..."
                  data-testid="submit-query"
                >
                  Run verified pipeline
                </button>
                <p class="text-sm text-stone-500">
                  `.env.local` switches to NVIDIA NIM automatically when a key is present.
                </p>
              </div>
            </.form>
          </section>

          <section class="prose prose-stone prose-lg max-w-none">
            <p class="not-prose text-[0.65rem] font-semibold uppercase tracking-[0.35em] text-stone-500">
              Verified output
            </p>

            <div
              id="katex-output"
              phx-hook="MathRender"
              phx-update="ignore"
              data-testid="katex-output"
              data-latex={@output_latex}
              class="min-h-16 py-4"
            >
            </div>

            <%= if @sympy_ast do %>
              <div class="not-prose mt-6 border-l border-stone-200 pl-5">
                <p class="font-serif text-2xl text-stone-900">{@sympy_ast.statement}</p>
                <p class="mt-3 font-mono text-sm text-stone-600">{@sympy_ast.expression}</p>

                <%= if @sympy_ast.notes != [] do %>
                  <ul class="mt-4 space-y-2 text-sm leading-6 text-stone-500">
                    <%= for note <- @sympy_ast.notes do %>
                      <li>{note}</li>
                    <% end %>
                  </ul>
                <% end %>
              </div>
            <% end %>

            <%= if @error_message do %>
              <p class="not-prose mt-6 text-sm leading-6 text-rose-700">
                {@error_message}
              </p>
            <% end %>
          </section>

          <%= if @layers.lean_proof do %>
            <section class="mt-16">
              <div class="mb-3 flex items-center justify-between gap-4">
                <p class="text-[0.65rem] font-semibold uppercase tracking-[0.35em] text-stone-500">
                  Proof boundary
                </p>
                <span class="font-mono text-[0.7rem] uppercase tracking-[0.24em] text-stone-500">
                  {@lean_proof_state || "Idle"}
                </span>
              </div>
              <pre
                class="overflow-x-auto border-l border-stone-200 pl-5 font-mono text-xs leading-7 text-stone-600"
                data-testid="proof-state"
              ><%= @proof_summary %></pre>
            </section>
          <% end %>

          <%= if @layers.desmos do %>
            <section class="mt-20">
              <div class="mb-5 flex items-center justify-between gap-4">
                <div>
                  <p class="text-[0.65rem] font-semibold uppercase tracking-[0.35em] text-stone-500">
                    Graph layer
                  </p>
                  <h2 class="mt-2 font-serif text-3xl text-stone-900">Desmos</h2>
                </div>
                <span class="font-mono text-[0.7rem] uppercase tracking-[0.24em] text-stone-500">
                  {if @is_verified, do: "live", else: "blocked"}
                </span>
              </div>
              <div
                id="desmos-surface"
                phx-hook="DesmosHook"
                phx-update="ignore"
                data-testid="desmos-surface"
                data-config={@desmos_json}
                class={[
                  "w-full overflow-hidden border-b border-stone-200 transition-[height] duration-300",
                  @is_verified && "h-[26rem]",
                  !@is_verified && "h-12"
                ]}
              >
              </div>
            </section>
          <% end %>

          <%= if @layers.geogebra do %>
            <section class="mt-20">
              <div class="mb-5 flex items-center justify-between gap-4">
                <div>
                  <p class="text-[0.65rem] font-semibold uppercase tracking-[0.35em] text-stone-500">
                    Graph layer
                  </p>
                  <h2 class="mt-2 font-serif text-3xl text-stone-900">GeoGebra</h2>
                </div>
                <span class="font-mono text-[0.7rem] uppercase tracking-[0.24em] text-stone-500">
                  v1
                </span>
              </div>
              <div
                id="geogebra-surface"
                phx-hook="GeoGebraHook"
                phx-update="ignore"
                data-testid="geogebra-surface"
                data-config={@geogebra_json}
                class={[
                  "w-full overflow-hidden border-b border-stone-200 transition-[height] duration-300",
                  @is_verified && "h-[26rem]",
                  !@is_verified && "h-12"
                ]}
              >
              </div>
            </section>
          <% end %>
        </section>
      </main>
    </Layouts.app>
    """
  end

  defp default_assigns do
    %{
      input_query: "",
      status: :idle,
      is_verified: false,
      sympy_ast: nil,
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
      desmos_json: "{}",
      geogebra_json: "{}",
      layers: %{
        desmos: true,
        geogebra: true,
        wolfram_steps: false,
        lean_proof: true
      }
    }
  end

  defp reset_assigns(layers, query, request_id, task_ref) do
    default_assigns()
    |> Map.merge(%{
      input_query: query,
      status: :computing,
      request_id: request_id,
      current_task_ref: task_ref,
      proof_summary: "Preparing the natural-language morphism.",
      layers: layers,
      form: to_form(%{"input_query" => query}, as: :prompt)
    })
  end

  defp result_assigns(result) do
    graph_config = %{desmos: result.graph.desmos, geogebra: result.graph.geogebra}

    %{
      status: result.status,
      is_verified: result.is_verified,
      sympy_ast: %{
        statement: result.symbol.statement,
        expression: result.symbol.expression,
        source: result.adapter,
        notes: result.symbol.notes
      },
      lean_proof_state: result.proof.state,
      proof_summary: result.proof.summary,
      graph_config: graph_config,
      output_latex: result.graph.latex_block || result.symbol.latex,
      error_message: result_error(result),
      adapter: result.adapter,
      timings: result.timings,
      desmos_json: Jason.encode!(Map.get(graph_config, :desmos, %{})),
      geogebra_json: Jason.encode!(Map.get(graph_config, :geogebra, %{}))
    }
  end

  defp result_error(%{error: nil}), do: nil

  defp result_error(%{error: :verification_failed}),
    do: "Verification failed, so graph rendering remains gated."

  defp result_error(%{error: error}), do: format_error(error)

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
      :desmos,
      "update_graph",
      Map.get(socket.assigns.graph_config, :desmos, %{})
    )
    |> maybe_push_graph_event(
      :geogebra,
      "geogebra:update",
      Map.get(socket.assigns.graph_config, :geogebra, %{})
    )
  end

  defp maybe_push_graph_event(socket, layer, event_name, payload) do
    if Map.get(socket.assigns.layers, layer) and payload != %{} do
      event_payload =
        if layer == :desmos do
          payload
        else
          %{graph: payload}
        end

      push_event(socket, event_name, event_payload)
    else
      socket
    end
  end

  defp format_status(:idle), do: "Idle"
  defp format_status(:computing), do: "Computing"
  defp format_status(:verifying), do: "Verifying"
  defp format_status(:rendering), do: "Rendering"
  defp format_status(:error), do: "Error"
  defp format_status(other), do: other |> to_string() |> String.capitalize()

  defp format_error(reason) when is_binary(reason), do: reason
  defp format_error(reason), do: inspect(reason)

  defp normalize_layer(layer) when is_binary(layer) do
    case layer do
      "desmos" -> :desmos
      "geogebra" -> :geogebra
      "wolfram_steps" -> :wolfram_steps
      "lean_proof" -> :lean_proof
      _ -> :unknown
    end
  end

  defp normalize_layer(layer) when is_atom(layer), do: layer

  defp layer_label(:desmos), do: "Desmos"
  defp layer_label(:geogebra), do: "GeoGebra"
  defp layer_label(:wolfram_steps), do: "Wolfram steps"
  defp layer_label(:lean_proof), do: "Lean proof"

  defp layer_description(:desmos),
    do: "Interactive graph surface updated from the verified payload."

  defp layer_description(:geogebra),
    do: "Secondary graphing lens for the same verified expression."

  defp layer_description(:wolfram_steps), do: "Reserved slot for external step-by-step traces."
  defp layer_description(:lean_proof), do: "Verifier transcript and proof summary."
end
