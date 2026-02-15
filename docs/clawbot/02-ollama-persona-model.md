# 02 - Ollama Persona Model (`cicero-clawbot`)

Goal: create a local Ollama model named `cicero-clawbot:latest` that embodies the Clawbot "Case Officer" vibe, but branded for Cicero.

## 1) Confirm a Base Model Exists

On the host:

```bash
bin/ollama list
```

Pick one you already have installed. Example:

- `llama3.1:8b-instruct-q4_K_M`

## 2) Create a Modelfile

Source-of-truth Modelfile:

- `pipelines/ollama/modelfiles/Modelfile-cicero-clawbot`

Critical: update the `FROM ...` line to match a model that exists in `bin/ollama list`.

## 3) Create the Model

```bash
bin/ollama create cicero-clawbot -f pipelines/ollama/modelfiles/Modelfile-cicero-clawbot
```

## 4) Verify

```bash
curl -sS http://127.0.0.1:11434/api/tags | head
bin/ollama list | grep -i cicero-clawbot
```

## 5) Smoke Test

```bash
bin/ollama run cicero-clawbot:latest "Reply with only: OK"
```

Expected: `OK`
