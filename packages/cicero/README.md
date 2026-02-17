# @slyfox-16/cicero

`@slyfox-16/cicero` is the v0 combined bundle + CLI package.

Included artifacts:

- `personality.txt`
- `configuration.yaml`
- `dist/manifest.json` (generated)
- `cicero` CLI

## CLI

Supported command:

- `cicero start`

Behavior in v0:

- Interactive text REPL only (`cicero> `)
- Ephemeral session (no persistence across runs)
- Ollama-only backend
- No memory integration yet
- No big-brain/Modal routing yet

Exit with `exit` or `Ctrl+C`.

## What Belongs Where

- `personality.txt`:
  - model behavior and style instructions
- `configuration.yaml`:
  - shared bundle defaults, including `backends.local.model_id`
- runtime environment config:
  - environment-specific values like Ollama host, Modal endpoint, and auth should be layered by runtime/deployment configuration
  - do not store secrets in this repository

## Ollama Setup

`cicero start` verifies Ollama connectivity at startup. Default base URL:

- `http://saturn:11434`

Override with environment variable:

```bash
export OLLAMA_BASE_URL=http://your-host:11434
```

If unreachable, the CLI prints steps to install/start Ollama and exits non-zero.

## Install

From GitHub Packages as a global CLI:

```bash
npm install -g @slyfox-16/cicero
```

Then run:

```bash
cicero start
```

## Release

From repo root, use the release helper script:

```bash
./scripts/release-cicero.sh 0.1.5
```

Or via npm script:

```bash
npm run release:cicero -- 0.1.5
```

What it does:

- bumps `packages/cicero/package.json` to the requested version
- rebuilds `packages/cicero/dist/manifest.json`
- commits release files
- creates tag `cicero-bundle-v<version>`
- pushes branch + tag to trigger GitHub Actions publish

Notes:

- requires a clean git working tree before running
- does not store any secrets in repository files

## Logging

Metadata-only logs are written to:

- `~/.cicero/logs/`

Each request logs:

- timestamp
- backend (`ollama`)
- model_id
- latency
- token counts when provided by Ollama

Prompts/responses are not logged by default.

## Roadmap Note

Memory integration, web UI, and big-brain routing are intentionally deferred to later packages/releases.
