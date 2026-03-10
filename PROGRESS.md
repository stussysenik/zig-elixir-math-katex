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

### Verification performed

- `mix test`
- `mix assets.build`
- `mix math.prove "Graph the derivative of x^2"`
- `bun run test:e2e`

### Open next slices

- Replace the mock verifier with a real Lean worker boundary.
- Add notebook persistence and export formats.
- Add vision ingestion and human-in-the-loop correction.
