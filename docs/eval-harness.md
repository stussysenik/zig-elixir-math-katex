# Evaluation Harness

This repo includes a small DSPy-based evaluation harness for checking AI response contract compliance.

## What it does

- Defines a Pydantic schema that mirrors the Ecto AIResponse + DesmosExpression contracts.
- Sends sample prompts to the configured NVIDIA NIM model.
- Scores each response based on strict JSON structure, mode alignment, and required reasoning steps.

## Where it lives

- `eval/dspy_optimizer.py` contains the DSPy signature and scoring harness.
- `eval/dataset.json` contains the input/expected pairs.

## Dependencies

The Python environment requires:

- dspy-ai
- pydantic
- requests

These are declared in `requirements.txt`.

## Running

Use the mix alias to run the eval through the repo's local .venv:

```bash
mix test.eval
```

The eval requires `NVIDIA_NIM_API_KEY` to be set.
