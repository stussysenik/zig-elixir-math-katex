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

  def handle_info({:DOWN, ref, :process, _pid, reason}, %{assigns: %{current_task_ref: ref}} = socket) do
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
      <main class="min-h-screen bg-[radial-gradient(circle_at_top,_#f4ede1,_#ebe4d5_42%,_#d8d0c2)] text-stone-900">
        <section class="mx-auto flex min-h-screen max-w-7xl flex-col gap-10 px-5 py-8 lg:px-10 lg:py-12">
        <header class="grid gap-8 rounded-[2rem] border border-stone-900/10 bg-white/80 p-8 shadow-[0_30px_80px_rgba(63,45,32,0.12)] backdrop-blur md:grid-cols-[1.3fr_0.7fr]">
          <div class="space-y-5">
            <p class="text-xs font-semibold uppercase tracking-[0.35em] text-amber-700">
              Verified-first mathematics over LiveView
            </p>
            <div class="space-y-4">
              <h1 class="font-serif text-4xl leading-tight text-balance md:text-6xl">
                One prompt, one formal gate, three synchronized layers.
              </h1>
              <p class="max-w-2xl text-base leading-7 text-stone-700 md:text-lg">
                Phoenix coordinates the natural-language morphism, a Lean-shaped verifier boundary, and graph payloads for KaTeX, Desmos, and GeoGebra. Rendering stays locked until verification passes.
              </p>
            </div>
          </div>

          <aside class="grid gap-4 rounded-[1.5rem] bg-stone-950 p-6 text-stone-100">
            <div>
              <p class="text-xs uppercase tracking-[0.3em] text-amber-300/80">Pipeline status</p>
              <p class="mt-3 text-3xl font-semibold" data-testid="status-label" data-status={@status}>
                {format_status(@status)}
              </p>
            </div>
            <div class="grid gap-3 text-sm text-stone-300">
              <div class="flex items-center justify-between rounded-xl border border-white/10 px-3 py-2">
                <span>Adapter</span>
                <strong class="font-medium text-stone-100">{String.upcase(to_string(@adapter || :stub))}</strong>
              </div>
              <div class="flex items-center justify-between rounded-xl border border-white/10 px-3 py-2">
                <span>Verified</span>
                <strong class={["font-medium", @is_verified && "text-emerald-300", !@is_verified && "text-rose-300"]}>
                  {if @is_verified, do: "true", else: "false"}
                </strong>
              </div>
            </div>
          </aside>
        </header>

        <section class="grid gap-8 lg:grid-cols-[0.95fr_1.05fr]">
          <div class="space-y-6">
            <div class="rounded-[2rem] border border-stone-900/10 bg-white/85 p-6 shadow-[0_20px_60px_rgba(63,45,32,0.10)]">
              <div class="mb-5 flex items-center justify-between gap-4">
                <div>
                  <p class="text-xs font-semibold uppercase tracking-[0.28em] text-amber-700">Natural language input</p>
                  <h2 class="mt-2 font-serif text-3xl">MathOrchestratorLive</h2>
                </div>
                <span class="rounded-full bg-stone-100 px-4 py-2 text-xs font-semibold uppercase tracking-[0.24em] text-stone-700">
                  CLI + Web shared pipeline
                </span>
              </div>

              <.form for={@form} id="solve-form" phx-submit="solve" class="space-y-4">
                <.input
                  field={@form[:input_query]}
                  type="textarea"
                  label="Prompt"
                  rows="5"
                  class="w-full rounded-[1.25rem] border border-stone-300 bg-stone-50 px-4 py-4 font-mono text-sm leading-6 text-stone-900 shadow-inner outline-none transition focus:border-amber-500 focus:ring-2 focus:ring-amber-200"
                  placeholder="Prove the derivative of sin(x), then show the verified graph."
                  data-testid="query-input"
                />
                <div class="flex flex-wrap items-center gap-3">
                  <button
                    type="submit"
                    class="rounded-full bg-stone-950 px-5 py-3 text-sm font-semibold text-white transition hover:bg-stone-800"
                    phx-disable-with="Translating..."
                    data-testid="submit-query"
                  >
                    Run verified pipeline
                  </button>
                  <p class="text-sm text-stone-600">
                    `.env.local` switches to NVIDIA NIM automatically when a key is present.
                  </p>
                </div>
              </.form>
            </div>

            <div class="rounded-[2rem] border border-stone-900/10 bg-[#fbf8f2] p-6 shadow-[0_20px_60px_rgba(63,45,32,0.08)]">
              <div class="mb-4 flex items-center justify-between">
                <div>
                  <p class="text-xs font-semibold uppercase tracking-[0.28em] text-amber-700">Layer toggles</p>
                  <h2 class="mt-2 font-serif text-3xl">Receiver-first views</h2>
                </div>
              </div>
              <div class="grid gap-3" data-testid="layer-toggles">
                <%= for {layer, enabled?} <- @layers do %>
                  <button
                    type="button"
                    phx-click="toggle_layer"
                    phx-value-layer={layer}
                    class={[
                      "flex items-center justify-between rounded-[1.2rem] border px-4 py-3 text-left transition",
                      enabled? && "border-emerald-500/40 bg-emerald-50",
                      !enabled? && "border-stone-200 bg-white"
                    ]}
                    data-testid={"toggle-#{layer}"}
                  >
                    <span>
                      <span class="block text-sm font-semibold uppercase tracking-[0.2em] text-stone-600">
                        {layer_label(layer)}
                      </span>
                      <span class="mt-1 block text-sm text-stone-500">
                        {layer_description(layer)}
                      </span>
                    </span>
                    <span class="rounded-full px-3 py-1 text-xs font-semibold uppercase tracking-[0.18em]">
                      {if enabled?, do: "On", else: "Off"}
                    </span>
                  </button>
                <% end %>
              </div>
            </div>

            <div class="rounded-[2rem] border border-stone-900/10 bg-white/85 p-6 shadow-[0_20px_60px_rgba(63,45,32,0.08)]">
              <p class="text-xs font-semibold uppercase tracking-[0.28em] text-amber-700">Pipeline timings</p>
              <div class="mt-4 grid gap-3 sm:grid-cols-3">
                <div class="rounded-[1.2rem] bg-stone-100 px-4 py-3">
                  <p class="text-xs uppercase tracking-[0.24em] text-stone-500">N -> S</p>
                  <p class="mt-2 text-2xl font-semibold">{Map.get(@timings, :nlp_ms, 0)} ms</p>
                </div>
                <div class="rounded-[1.2rem] bg-stone-100 px-4 py-3">
                  <p class="text-xs uppercase tracking-[0.24em] text-stone-500">S -> L</p>
                  <p class="mt-2 text-2xl font-semibold">{Map.get(@timings, :verify_ms, 0)} ms</p>
                </div>
                <div class="rounded-[1.2rem] bg-stone-100 px-4 py-3">
                  <p class="text-xs uppercase tracking-[0.24em] text-stone-500">S -> G</p>
                  <p class="mt-2 text-2xl font-semibold">{Map.get(@timings, :graph_ms, 0)} ms</p>
                </div>
              </div>
            </div>
          </div>

          <div class="space-y-6">
            <div class="rounded-[2rem] border border-stone-900/10 bg-white/90 p-6 shadow-[0_20px_60px_rgba(63,45,32,0.10)]">
              <div class="mb-5 flex items-center justify-between gap-4">
                <div>
                  <p class="text-xs font-semibold uppercase tracking-[0.28em] text-amber-700">Typeset output</p>
                  <h2 class="mt-2 font-serif text-3xl">KaTeX layer</h2>
                </div>
                <span class="rounded-full bg-stone-100 px-4 py-2 text-xs font-semibold uppercase tracking-[0.22em] text-stone-600">
                  {if @is_verified, do: "Verified", else: "Awaiting proof"}
                </span>
              </div>

              <div class="grid gap-4">
                <div
                  id="katex-output"
                  phx-hook="MathRender"
                  phx-update="ignore"
                  data-testid="katex-output"
                  data-latex={@output_latex}
                  class="min-h-28 rounded-[1.4rem] border border-dashed border-stone-300 bg-[#fffdfa] px-6 py-8"
                >
                </div>

                <%= if @sympy_ast do %>
                  <div class="grid gap-3 rounded-[1.4rem] bg-stone-950 px-5 py-4 text-sm text-stone-200">
                    <div class="flex items-center justify-between gap-3">
                      <span class="uppercase tracking-[0.22em] text-stone-400">Symbolic state</span>
                      <span class="rounded-full bg-white/10 px-3 py-1 text-xs uppercase tracking-[0.18em]">
                        {@sympy_ast.source}
                      </span>
                    </div>
                    <p><strong class="text-stone-100">Statement:</strong> {@sympy_ast.statement}</p>
                    <p><strong class="text-stone-100">Expression:</strong> {@sympy_ast.expression}</p>
                    <%= if @sympy_ast.notes != [] do %>
                      <ul class="list-disc space-y-1 pl-5 text-stone-300">
                        <%= for note <- @sympy_ast.notes do %>
                          <li>{note}</li>
                        <% end %>
                      </ul>
                    <% end %>
                  </div>
                <% end %>

                <%= if @error_message do %>
                  <div class="rounded-[1.2rem] border border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-900">
                    {@error_message}
                  </div>
                <% end %>
              </div>
            </div>

            <%= if @layers.lean_proof do %>
              <div class="rounded-[2rem] border border-stone-900/10 bg-[#111111] p-6 text-stone-100 shadow-[0_20px_60px_rgba(63,45,32,0.10)]">
                <div class="mb-4 flex items-center justify-between">
                  <div>
                    <p class="text-xs font-semibold uppercase tracking-[0.28em] text-amber-300">Proof boundary</p>
                    <h2 class="mt-2 font-serif text-3xl">Lean-shaped verifier</h2>
                  </div>
                  <span class="rounded-full bg-white/10 px-4 py-2 text-xs font-semibold uppercase tracking-[0.22em]">
                    {@lean_proof_state || "Idle"}
                  </span>
                </div>
                <p class="text-sm leading-7 text-stone-300" data-testid="proof-state">
                  {@proof_summary}
                </p>
              </div>
            <% end %>

            <%= if @layers.desmos do %>
              <div class="rounded-[2rem] border border-stone-900/10 bg-white/90 p-6 shadow-[0_20px_60px_rgba(63,45,32,0.10)]">
                <div class="mb-4 flex items-center justify-between">
                  <div>
                    <p class="text-xs font-semibold uppercase tracking-[0.28em] text-amber-700">Graph layer</p>
                    <h2 class="mt-2 font-serif text-3xl">Desmos</h2>
                  </div>
                  <span class="rounded-full bg-stone-100 px-4 py-2 text-xs font-semibold uppercase tracking-[0.22em] text-stone-600">
                    {if @is_verified, do: "Live", else: "Blocked"}
                  </span>
                </div>
                <div
                  id="desmos-surface"
                  phx-hook="DesmosHook"
                  phx-update="ignore"
                  data-testid="desmos-surface"
                  data-config={@desmos_json}
                  class="h-[22rem] overflow-hidden rounded-[1.4rem] border border-stone-200 bg-stone-50"
                >
                </div>
              </div>
            <% end %>

            <%= if @layers.geogebra do %>
              <div class="rounded-[2rem] border border-stone-900/10 bg-white/90 p-6 shadow-[0_20px_60px_rgba(63,45,32,0.10)]">
                <div class="mb-4 flex items-center justify-between">
                  <div>
                    <p class="text-xs font-semibold uppercase tracking-[0.28em] text-amber-700">Graph layer</p>
                    <h2 class="mt-2 font-serif text-3xl">GeoGebra</h2>
                  </div>
                  <span class="rounded-full bg-stone-100 px-4 py-2 text-xs font-semibold uppercase tracking-[0.22em] text-stone-600">
                    V1
                  </span>
                </div>
                <div
                  id="geogebra-surface"
                  phx-hook="GeoGebraHook"
                  phx-update="ignore"
                  data-testid="geogebra-surface"
                  data-config={@geogebra_json}
                  class="h-[22rem] overflow-hidden rounded-[1.4rem] border border-stone-200 bg-stone-50"
                >
                </div>
              </div>
            <% end %>
          </div>
        </section>
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
  defp result_error(%{error: :verification_failed}), do: "Verification failed, so graph rendering remains gated."
  defp result_error(%{error: error}), do: format_error(error)

  defp maybe_assign_status(socket, request_id, status) when request_id == socket.assigns.request_id do
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
    assign(socket, sympy_ast: %{statement: "Pending verification", expression: expression, source: socket.assigns.adapter, notes: []})
  end

  defp maybe_assign_symbol_preview(socket, _request_id, _payload), do: socket

  defp maybe_push_graph_events(%{assigns: %{is_verified: false}} = socket), do: socket

  defp maybe_push_graph_events(socket) do
    socket
    |> maybe_push_graph_event(:desmos, "desmos:update", Map.get(socket.assigns.graph_config, :desmos, %{}))
    |> maybe_push_graph_event(:geogebra, "geogebra:update", Map.get(socket.assigns.graph_config, :geogebra, %{}))
  end

  defp maybe_push_graph_event(socket, layer, event_name, payload) do
    if Map.get(socket.assigns.layers, layer) and payload != %{} do
      push_event(socket, event_name, %{graph: payload})
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

  defp layer_description(:desmos), do: "Interactive graph surface updated from the verified payload."
  defp layer_description(:geogebra), do: "Secondary graphing lens for the same verified expression."
  defp layer_description(:wolfram_steps), do: "Reserved slot for external step-by-step traces."
  defp layer_description(:lean_proof), do: "Verifier transcript and proof summary."
end
