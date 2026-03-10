# Progress

## 2026-03-10

### Checkpoint 1

- Scaffolded a fresh Phoenix 1.8 LiveView app in-place with `--no-ecto`.
- Switched the repo to Bun-managed frontend dependencies.
- Added `flake.nix`, `.env.example`, and repo hygiene updates.

### Checkpoint 2

- Implemented the CLI-first pipeline in Elixir.
- Added explicit object-state structs for query, symbol, proof, graph, and result aggregation.
- Added dual `N -> S` adapters:
  - deterministic stub
  - NVIDIA NIM HTTP adapter
- Added the mock verifier gate and graph payload builder.
- Added `mix math.prove`.

### Checkpoint 3

- Replaced the default Phoenix landing page with `MathOrchestratorLive`.
- Added server-owned LiveView state for:
  - query input
  - status
  - verification gate
  - symbolic payload
  - proof state
  - graph config
  - layer toggles
- Added KaTeX, Desmos, and GeoGebra hooks.
- Moved third-party graph script loading into the JS layer so LiveView still boots cleanly.

### Checkpoint 4

- Added ExUnit tests for the pipeline and LiveView.
- Added Playwright E2E coverage for:
  - prompt submission
  - KaTeX rendering
  - proof output
  - Desmos layer toggle
- Fixed the Playwright harness by:
  - moving test traffic to `localhost`
  - forcing `PHX_SERVER=true`
  - fixing runtime port handling

### Checkpoint 5

- Replaced the card-heavy dashboard layout with a single-column document flow.
- Moved engine metadata into a compact sticky `details` panel instead of giving it equal weight with the math.
- Reduced empty graph space before verification by collapsing the graph surfaces until a verified payload exists.
- Added a configurable Desmos API key path with the documented demo key as the default development fallback.

### Checkpoint 6

- Added `MathViz.Contracts` for the AI response, SymPy request/response, and Desmos payload boundaries.
- Switched the pipeline to `N -> AI contract -> SymPy execution -> verifier -> graph payloads`.
- Added a supervised Python SymPy Port worker and the `priv/python/sympy_runner.py` bridge.
- Updated the Desmos hook to consume an `expressions` list via `push_event("update_graph", payload)`.
- Added contract tests, SymPy worker tests, refreshed pipeline/LiveView assertions, and a new Playwright happy-path spec.
- Updated project setup to create a local `.venv` and install SymPy there.

### Checkpoint 7

- Reworked the input form so the textarea reads as a real writing surface instead of inline document text.
- Promoted the submit action into a proper primary button with clear visual weight.
- Forced Desmos and GeoGebra surfaces to hold a stable `aspect-video` canvas with a `min-h-[400px]` floor so the hooks no longer collapse into slivers.
- Added larger vertical spacing between the document blocks and tightened the LiveView test to wait for async pipeline completion instead of using a fixed sleep.

### Checkpoint 8

- Rebuilt the LiveView shell around a mobile-first blank canvas instead of a document hero.
- Moved the query form into a sticky bottom command bar and removed explanatory copy from the default state.
- Switched graph rendering from stacked sections to a single tabbed surface with `Desmos` selected by default.
- Hid output, proof, and graph sections entirely until the pipeline actually has data to render.
- Simplified the graph hooks so they fall back to quiet visual shells instead of helper text while loading.

### Checkpoint 9

- Added the first visible multimodal affordances to the command bar: a paperclip trigger, hidden image file input, and microcopy for textbook and whiteboard uploads.
- Added a drag-over hook so the command surface tints and gains a dashed ring when files hover over the window.
- Kept engine diagnostics fully tucked behind the top-right trigger so the empty state still reads as a blank canvas.

### Checkpoint 10

- Added `ecto` embedded-schema validation for headless solve requests, vision payloads, and normalized solve responses.
- Added the shared `MathViz.Solve` service so the API, LiveView, and CLI all use the same validated request path.
- Added `POST /api/solve` with JSON and multipart support for text plus optional image uploads.
- Switched the LiveView command bar from a cosmetic file input to native `allow_upload` and `live_file_input` handling.
- Threaded optional vision bytes through the NIM adapter as OpenAI-compatible multimodal `content` parts.
- Moved the default NIM model to `moonshotai/kimi-k2-5` so vision works out of the box when a key is present.
- Ensured the app creates a writable local `tmp/` directory on boot so LiveView uploads work reliably in tests and dev.

### Verification performed

- `mix test`
- `mix assets.build`
- `mix math.prove "Graph the derivative of x^2"`
- `bun run test:e2e`
- `curl -sS -X POST http://127.0.0.1:4000/api/solve -H 'content-type: application/json' -d '{"query":"Graph the derivative of x^2"}'`
- `curl -sS -X POST http://127.0.0.1:4000/api/solve -F 'query=' -F 'image=@/tmp/mathviz-upload.png;type=image/png'`

### Open next slices

- Replace the mock verifier with a real Lean worker boundary.
- Add notebook persistence and export formats.
- Add human-in-the-loop OCR correction for ambiguous vision parses.

### Checkpoint 11

- Tightened AI response contract validation with embedded schemas for AIResponse and DesmosExpression.
- Switched parse_ai_response/1 to apply the AIResponse changeset and return Ecto changeset errors.
- Added SymPy worker timeout/exit handling for safer pipeline failures.
- Added LiveView task cancellation + timeout handling and a keyboard submit hook on the prompt textarea.
- Hardened the Desmos hook lifecycle with script-load state and calculator cleanup.
- Added a DSPy evaluation harness and dataset, plus Python deps and a mix test.eval alias.
- Updated contract tests to assert validation errors via Ecto changesets.

### Checkpoint 12

- Added `MathViz.RuntimeEnv` so runtime config accepts both `NVIDIA_NIM_API_KEY` and legacy `NIM_API_KEY`.
- Changed development fallback policy so NIM routing failures surface directly in the UI instead of silently swapping to the stub.
- Added a new `mix qa.report` harness that runs ExUnit, Playwright, and Cypress smoke lanes and writes:
  - `tmp/qa/latest/report.md`
  - `tmp/qa/latest/summary.json`
  - `tmp/qa/latest/tool_call_graph.json`
  - per-lane raw logs under `tmp/qa/latest/raw/`
- Added internal pipeline call-graph instrumentation for harness probe runs without introducing an Ecto repo or SQLite.
- Added Cypress smoke coverage mirroring the existing Playwright happy paths.
- Added harness-level tests for call-graph capture, Markdown rendering, and artifact generation.

### Verification performed

- `mix qa.report --scope smoke --browser playwright`
- `mix qa.report --scope smoke --browser all`
- `mix precommit`

### Current state

- The QA harness is green across ExUnit, Playwright, and Cypress smoke lanes.
- The app now boots into `:dual` mode when only the legacy `NIM_API_KEY` is present.
- Strict development mode now exposes real NIM errors; the current live NIM issue is an HTTP `404`, not silent stub fallback.
