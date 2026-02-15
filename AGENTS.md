# AGENTS.md (Cicero)

## Repo-Local Tool Installs (Required For Clawbot Work)

This repo keeps **Clawbot-related installs** inside the repository so setup is reproducible and doesn’t depend on global system state.

Conventions:

- Repo-local installs live under `tools/`.
- Installed binaries, model blobs, and `node_modules/` are **not committed** (see `.gitignore`).
- Documentation and templates that describe the installs *are* committed.
- Docs and scripts should invoke tools via `bin/` wrappers (not raw paths).

Canonical repo root (for `saturn` docs/unit files):

- `"$HOME/cicero"`

## Navigation

- Docs index: `docs/README.md`
- Clawbot docs: `docs/clawbot/README.md`
- Ollama pipeline: `pipelines/ollama/README.md`
- Saturn ops: `ops/saturn/README.md`

### Ollama (repo-local)

- Repo-local binary (optional): `tools/ollama/bin/ollama` (gitignored)
- Modelfiles (committed): `pipelines/ollama/modelfiles/`
- Model data (optional, gitignored): `tools/ollama/models/`
- Wrapper: `bin/ollama`

### OpenClaw (repo-local Node install)

OpenClaw is installed locally under `tools/openclaw/`:

- `tools/openclaw/node_modules/.bin/openclaw` (gitignored)
- Wrapper: `bin/openclaw`

Install instructions live in:

- `tools/openclaw/README.md`

### Clawbot Setup Docs

Clawbot setup docs are in-repo and should be treated as the source of truth:

- `docs/clawbot/README.md`

## Skills (Codex)

A skill is a set of local instructions to follow that is stored in a `SKILL.md` file. Below is the list of skills that can be used. Each entry includes a name, description, and file path so you can open the source for full instructions when using a specific skill.

### Available skills

- skill-creator: Guide for creating effective skills. Use when creating or updating a skill. (file: `/home/carlos/.codex/skills/.system/skill-creator/SKILL.md`)
- skill-installer: Install Codex skills into `$CODEX_HOME/skills` from a curated list or a GitHub repo path. (file: `/home/carlos/.codex/skills/.system/skill-installer/SKILL.md`)

### How to use skills

- Discovery: The list above is the skills available in this session (name + description + file path). Skill bodies live on disk at the listed paths.
- Trigger rules: If the user names a skill (with `$SkillName` or plain text) OR the task clearly matches a skill's description shown above, you must use that skill for that turn. Multiple mentions mean use them all. Do not carry skills across turns unless re-mentioned.
- Missing/blocked: If a named skill isn't in the list or the path can't be read, say so briefly and continue with the best fallback.
- How to use a skill (progressive disclosure):
  1) After deciding to use a skill, open its `SKILL.md`. Read only enough to follow the workflow.
  2) When `SKILL.md` references relative paths (e.g., `scripts/foo.py`), resolve them relative to the skill directory listed above first, and only consider other paths if needed.
  3) If `SKILL.md` points to extra folders such as `references/`, load only the specific files needed for the request; don't bulk-load everything.
  4) If `scripts/` exist, prefer running or patching them instead of retyping large code blocks.
  5) If `assets/` or templates exist, reuse them instead of recreating from scratch.
- Coordination and sequencing:
  - If multiple skills apply, choose the minimal set that covers the request and state the order you'll use them.
  - Announce which skill(s) you're using and why (one short line). If you skip an obvious skill, say why.
- Context hygiene:
  - Keep context small: summarize long sections instead of pasting them; only load extra files when needed.
  - Avoid deep reference-chasing: prefer opening only files directly linked from `SKILL.md` unless you're blocked.
  - When variants exist (frameworks, providers, domains), pick only the relevant reference file(s) and note that choice.
- Safety and fallback: If a skill can't be applied cleanly (missing files, unclear instructions), state the issue, pick the next-best approach, and continue.
