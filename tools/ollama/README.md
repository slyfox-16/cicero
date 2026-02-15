# Ollama (Repo-Local)

This repo supports an optional repo-local Ollama binary at:

- `tools/ollama/bin/ollama`

Suggested layout:

- `tools/ollama/bin/` (gitignored): put the `ollama` binary here
- `pipelines/ollama/modelfiles/` (committed): Modelfiles/templates you author in this repo
- `tools/ollama/models/` (gitignored): optional, if you decide to store model blobs under the repo

## Install (Repo-Local)

Use the pinned installer:

```bash
OLLAMA_VERSION="PIN_ME" OLLAMA_SHA256="PIN_ME" tools/ollama/install.sh
bin/ollama --version
```

Quick check (run from repo root):

```bash
bin/ollama --version
bin/ollama list
```
