# 02 - Ollama Persona Model (`cicero-clawbot`)

Goal: create a local Ollama model named `cicero-clawbot:latest` that embodies the Clawbot "Case Officer" vibe, but branded for Cicero.

## 1) Confirm a Base Model Exists

On the host:

```bash
ollama list
```

Pick one you already have installed. Example:

- `llama3.1:8b-instruct-q4_K_M`

## 2) Create a Modelfile

Suggested location:

```bash
mkdir -p ~/ollama
```

Create `~/ollama/Modelfile-cicero-clawbot` by starting from:

- `clawbot/templates/Modelfile-cicero-clawbot`

Critical: update the `FROM ...` line to match a model that exists in `ollama list`.

## 3) Create the Model

```bash
ollama create cicero-clawbot -f ~/ollama/Modelfile-cicero-clawbot
```

## 4) Verify

```bash
curl -sS http://127.0.0.1:11434/api/tags | head
ollama list | grep -i cicero-clawbot
```

## 5) Smoke Test

```bash
ollama run cicero-clawbot:latest "Reply with only: OK"
```

Expected: `OK`

