# MathViz

Verified-first math orchestration built on Phoenix LiveView.

The current app ships a greenfield Phoenix 1.8 LiveView surface with:

- a headless-first `/api/solve` endpoint for `curl`, uploads, and JSON clients
- a shared CLI and web pipeline
- a dual `N -> S` morphism (`stub` fallback plus NVIDIA NIM adapter)
- strict AI, SymPy, and Desmos boundary contracts
- Ecto embedded-schema validation for headless request/response payloads
- a supervised Python SymPy Port worker
- a mocked Lean-shaped verifier gate
- KaTeX rendering
- Desmos and GeoGebra layer hooks
- Playwright and ExUnit coverage for the shipped flow

The design goal is simple: do not render graph layers until verification passes.

## What Ships Today

### Core pipeline

- `MathViz.Pipeline.run/2` is the single entrypoint for web and CLI flows.
- `MathViz.Solve.run/2` is the validated headless service used by the API, LiveView, and CLI.
- `mix math.prove "derivative of sin(x)"` runs the same orchestration as the LiveView.
- `MathViz.Contracts` validates the AI response shape, SymPy request/response, and the Desmos payload contract.
- `MathViz.Morphisms.NlpRouter.Stub` handles deterministic local parsing.
- `MathViz.Morphisms.NlpRouter.Nim` calls NVIDIA NIM with an OpenAI-compatible `chat/completions` request, supports multimodal `text + image_url` content parts, and requests JSON-schema output first.
- `MathViz.Engines.SymPyWorker` executes the symbolic step through a long-lived Python Port.
- `MathViz.Morphisms.Verifier.Mock` simulates the Lean verification boundary and hard-gates graph rendering.
- `MathViz.Morphisms.GraphBuilder.Default` produces Desmos and GeoGebra payloads from the verified symbolic state.

### Web UI

- `MathOrchestratorLive` owns the pipeline state, conditional output rendering, and graph tab state.
- KaTeX output is rendered via a LiveView hook.
- Desmos and GeoGebra are loaded lazily from the browser and only receive payloads after verification succeeds.
- The default web shell is intentionally sparse: a blank canvas, a bottom command bar, and output that appears only when data exists.
- The command bar now uses native LiveView uploads with drag-and-drop, picker uploads, and a shared 5MB image validation path.

### Headless API

- `POST /api/solve` is the browser-independent entrypoint.
- It accepts:
  - `application/json` with `query`, optional `image_base64`, optional `image_mime`
  - `multipart/form-data` with `query` and optional `image`
- It returns one normalized JSON payload with:
  - request metadata
  - adapter used
  - verified symbolic output
  - proof state
  - graph payloads
  - timings

## Setup

### Local prerequisites

- Elixir / Erlang
- Bun
- Node-compatible browser tooling for Playwright
- Optional: `nix develop` via `flake.nix`

### Install

```bash
mix setup
```

`mix setup` creates a local `.venv`, installs `requirements.txt` into it, then builds the assets.

### Environment

Create `.env.local` from `.env.example`.

```bash
cp .env.example .env.local
```

Supported variables:

- `MATH_VIZ_NLP_MODE=stub|nim|dual`
- `NVIDIA_NIM_API_KEY`
- `NVIDIA_NIM_BASE_URL`
- `NVIDIA_NIM_MODEL`
- `NVIDIA_NIM_TIMEOUT_MS`
- `DESMOS_API_KEY`

Behavior:

- `stub`: always uses the deterministic parser
- `nim`: always uses NVIDIA NIM and errors if the key is missing
- `dual`: tries NVIDIA NIM first, then falls back to the stub adapter
- `NVIDIA_NIM_MODEL` defaults to `moonshotai/kimi-k2-5` for multimodal requests
- `DESMOS_API_KEY` defaults to Desmos' documented demo key for development

## Run

### Web

```bash
mix phx.server
```

Open [http://localhost:4000](http://localhost:4000).

### CLI

```bash
mix math.prove "derivative of sin(x)"
```

### Headless text solve

```bash
curl -sS -X POST http://127.0.0.1:4000/api/solve \
  -H 'content-type: application/json' \
  -d '{"query":"Graph the derivative of x^2"}'
```

### Headless image solve

```bash
curl -sS -X POST http://127.0.0.1:4000/api/solve \
  -F 'query=' \
  -F 'image=@/absolute/path/to/whiteboard.png;type=image/png'
```

### Headless base64 image solve

```bash
curl -sS -X POST http://127.0.0.1:4000/api/solve \
  -H 'content-type: application/json' \
  -d '{"query":"Solve the equation in the image","image_mime":"image/png","image_base64":"<BASE64_HERE>"}'
```

## Test And Build

### Elixir tests

```bash
mix test
```

### Assets

```bash
mix assets.build
```

### Browser tests

```bash
bun run playwright:install
bun run test:e2e
```

## Prompt Smoke Tests

Use these as original, engineering-math-style prompts for quick verification:

- `Graph the derivative of x^2`
- `Find the Laplace transform of e^(2x) sin(x)`
- `Solve the first-order ODE y' + 3y = 6`
- `Expand the Fourier series of x on [-pi, pi]`
- `Given the uploaded whiteboard image, transcribe the equation and solve for the derivative`

## Repo Notes

- `PROGRESS.md` tracks the implementation checkpoints and verification steps.
- `flake.nix` provides a reproducible shell for Elixir, Bun, Python, SymPy, and `elan`.
- The current verifier is intentionally mocked; Lean is still the next major integration.
- Vision ingest is now wired through LiveView uploads and the headless API, but human-in-the-loop OCR correction, persistence, and exports are still not in this version.
