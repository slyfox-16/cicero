# CLAUDE.md — Cicero Repo

This repo is Cicero's configuration — personality, workspace files, skills, and deploy scripts. It is not Cicero itself. The runtime is OpenClaw + Ollama running on minerva. Edits here are live immediately (workspace is symlinked into the running agent).

---

## What this repo contains

```
cicero/
├── workspace/              Agent's live files — symlinked to ~/.openclaw/workspace
│   ├── SOUL.md             Voice and behavioral rules. Edit deliberately.
│   ├── IDENTITY.md         Name, vibe, surface metadata.
│   ├── AGENTS.md           Workspace conventions and memory rules.
│   ├── USER.md             Context about Carlos (the user).
│   ├── TOOLS.md            Environment specifics — hostnames, models, data sources.
│   ├── HEARTBEAT.md        Periodic task checklist (currently passive).
│   └── skills/             Workspace-level skills, auto-discovered by OpenClaw.
│       ├── cicero-health/  Stub. Postgres not yet wired.
│       └── cicero-memory/  Stub. Chroma not yet wired.
├── deploy/
│   ├── mac/
│   │   ├── setup.sh                   Idempotent Mac installer (active).
│   │   └── ai.openclaw.gateway.plist  launchd unit template (token templated).
│   └── saturn/                        Legacy Linux deploy. Not the active path.
├── scripts/
│   └── cicero                         CLI wrapper: `cicero chat` / `cicero ask`
└── docs/
    ├── architecture.md    Current design and decisions log.
    ├── roadmap.md         Upcoming workstreams in priority order.
    ├── security.md        Operational discipline for running LLMs locally.
    └── scope.md           What Cicero is and is not.
```

---

## Running Cicero

```bash
cicero chat          # TUI session (embedded local agent, no gateway needed)
cicero ask "..."     # One-shot via gateway
```

Gateway health:
```bash
launchctl print "gui/$(id -u)/ai.openclaw.gateway" | head
tail ~/Library/Logs/openclaw-gateway.err.log
```

Restart gateway (required after openclaw.json changes):
```bash
launchctl kickstart -k "gui/$(id -u)/ai.openclaw.gateway"
```

---

## Developer guide

### Editing personality / behavior

Files in `workspace/` are read at session start and injected into the system prompt. Edits are live — no restart needed for `cicero chat`. For `cicero ask` (gateway path), edits are also live per-session; only `openclaw.json` changes need a gateway restart.

| File | Edit when |
|---|---|
| `SOUL.md` | Changing voice, tone, behavioral rules |
| `IDENTITY.md` | Changing name, vibe, avatar |
| `USER.md` | Updating context about Carlos |
| `TOOLS.md` | Adding a new host, data source, or model |
| `AGENTS.md` | Changing workspace conventions or memory rules |

**SOUL.md authoring rules:**
- Keep language natural and descriptive, not imperative or defensive.
- Do not use aggressive override phrasing ("CRITICAL RULE", "never reveal training") — it causes refusal behavior on deepseek-r1.
- The identity line that works: `You are Cicero — a personal AI assistant. That is your name and your identity.`
- deepseek-r1:14b respects the persona as written. No special anchoring needed.

### Verifying workspace injection

The session `.jsonl` log does not contain the system prompt. Check the trajectory:

```bash
python3 - <<'PY'
import json, glob, os
sessions = glob.glob(os.path.expanduser("~/.openclaw/agents/main/sessions/*.trajectory.jsonl"))
latest = max(sessions, key=os.path.getmtime)
with open(latest) as f:
    for line in f:
        msg = json.loads(line)
        if msg.get("type") == "context.compiled":
            sp = msg["data"]["systemPrompt"]
            print("Injected:", "SOUL" in sp and "Cicero" in sp)
            print("System prompt length:", len(sp), "chars")
            break
PY
```

Healthy output: `Injected: True`, length ~15-17K chars. If length is ~3-4K, workspace files are missing.

### Changing the model

1. Pull the model: `ollama pull <model>`
2. Update `openclaw.json`: `openclaw config get agents.defaults` → edit `model.primary`
3. Update `deploy/mac/setup.sh`: change the `MODEL=` line
4. Update `workspace/TOOLS.md`: note the model under the minerva host entry
5. Restart the gateway: `launchctl kickstart -k "gui/$(id -u)/ai.openclaw.gateway"`
6. **Test persona compliance in a fresh session:**
   ```bash
   openclaw agent --agent main --session-id "test-$(date +%s%N)" --message "What is your name?"
   ```
   Expected: answers as Cicero. If it says "Qwen", "Assistant", or the model vendor — the model's RLHF training overrides persona instructions. Try a different model.

**Known persona compliance:**
- `deepseek-r1:14b` ✅ Holds Cicero identity reliably.
- `qwen3:*` ❌ RLHF training overrides system prompt identity. Not fixable with prompt engineering.

### Adding or updating a skill

Skills live in `workspace/skills/<skill-name>/`. Each needs a `SKILL.md` that OpenClaw auto-discovers. A real skill also needs a dispatch mechanism (HTTP endpoint or subprocess call) — prose-only skills route inconsistently.

To add a skill:
1. Create `workspace/skills/<skill-name>/SKILL.md` describing what it does and how to invoke it.
2. Test routing: `cicero ask "use the <skill> skill to ..."` in a fresh session.
3. If routing is unreliable, add an explicit tool call (HTTP/subprocess) to SKILL.md.

### Re-running setup (fresh machine or after a wipe)

```bash
cd ~/cicero
./deploy/mac/setup.sh
```

If it stops asking for `openclaw onboard` — that means `~/.openclaw/openclaw.json` is missing. The script now handles this automatically (non-interactive onboard), but on a truly fresh machine with no prior OpenClaw state it will run onboard as part of setup.

**Critical: after any `openclaw onboard` run**, check for `skipBootstrap`:
```bash
openclaw config get agents.defaults
```
If `skipBootstrap: true` is present, remove it or workspace files will not inject:
```bash
python3 -c "
import json, pathlib
p = pathlib.Path.home() / '.openclaw' / 'openclaw.json'
c = json.loads(p.read_text())
c['agents']['defaults'].pop('skipBootstrap', None)
p.write_text(json.dumps(c, indent=2))
print('done')
"
```
`deploy/mac/setup.sh` removes this automatically on every run.

---

## Common failure modes

| Symptom | Cause | Fix |
|---|---|---|
| Cicero answers as "Assistant" / "Qwen" / model vendor | `skipBootstrap: true` in openclaw.json | Remove it (see above) |
| Cicero answers as "Assistant" / "Qwen" even after fix | Wrong model — RLHF identity anchoring | Switch to deepseek-r1:14b |
| `cicero ask` hangs or errors | Gateway not running | `launchctl kickstart -k "gui/$(id -u)/ai.openclaw.gateway"` |
| SOUL.md edit has no effect on `cicero ask` | openclaw.json change needs restart | Restart gateway |
| Workspace symlink wrong after worktree cleanup | Symlink pointed at worktree path | `ln -sfn ~/cicero/workspace ~/.openclaw/workspace` |
| Onboard re-run changed default model | `openclaw onboard` auto-pulls gemma4 | Re-pin: `openclaw config get agents.defaults`, update `model.primary` |

---

## Key paths on minerva

| Path | What |
|---|---|
| `~/cicero/` | This repo (source of truth) |
| `~/.openclaw/openclaw.json` | OpenClaw runtime config (model, gateway token, auth) |
| `~/.openclaw/workspace` | Symlink → `~/cicero/workspace` |
| `~/.openclaw/agents/main/` | Session history, agent auth state |
| `~/Library/LaunchAgents/ai.openclaw.gateway.plist` | launchd gateway unit (rendered from deploy/mac template) |
| `~/Library/Logs/openclaw-gateway.err.log` | Gateway error log |
| `~/.local/bin/cicero` | CLI shim → `~/cicero/scripts/cicero` |
