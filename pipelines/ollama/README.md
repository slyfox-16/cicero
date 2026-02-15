# Ollama Pipelines

This folder is for **reproducible** Ollama workflows used by Cicero.

Scope (current):

- Build the Cicero/Clawbot persona model (`cicero-clawbot:latest`) from a committed Modelfile
- Run lightweight, prompt-based evals and record outputs locally (gitignored)

## Build Persona Model

From repo root:

```bash
pipelines/ollama/scripts/build-persona.sh
```

Source-of-truth Modelfile:

- `pipelines/ollama/modelfiles/Modelfile-cicero-clawbot`

## Run Evals

From repo root:

```bash
pipelines/ollama/scripts/run-evals.sh
```

Prompts live in:

- `pipelines/ollama/evals/prompts/`

Runs are written to (gitignored):

- `pipelines/ollama/evals/runs/<timestamp>/`

