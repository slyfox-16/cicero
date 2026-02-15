# Repo-Local Tools

This folder is for repo-local installs used by Clawbot (and related development tooling).

Rules:

- Large installs and downloaded binaries live under `tools/**` and are **gitignored**.
- Only small docs/templates in `tools/**` should be committed.

Entry points:

- Ollama (repo-local): `tools/ollama/README.md`
- OpenClaw (repo-local): `tools/openclaw/README.md`

Tool wrappers (preferred for docs/scripts):

- `bin/ollama`
- `bin/openclaw`
