# OpenClaw Injection Notes

This note records practical guidance for verifying and troubleshooting agent injection when using OpenClaw and local Claude-style integration.

1. `skipBootstrap` can disable injection silently.
   - If OpenClaw onboard is re-run, it may set `skipBootstrap: true` in `~/.openclaw/openclaw.json` under `agents.defaults`.
   - Check with:
     ```sh
     openclaw config get agents.defaults
     ```
   - If present, remove it with:
     ```sh
     python3 -c "import json,pathlib; p=pathlib.Path.home()/'.openclaw'/'openclaw.json'; c=json.loads(p.read_text()); c['agents']['defaults'].pop('skipBootstrap',None); p.write_text(json.dumps(c,indent=2))"
     ```

2. Verify injection via the trajectory, not the session log.
   - Session `.jsonl` has no system prompt entry.
   - Check `context.compiled` in the trajectory file.
   - If system prompt length is >10K and contains `SOUL`, injection is working.

3. `SOUL.md` edits are live immediately for cicero chat (`--local embedded`).
   - `openclaw.json` changes (model, token) require a gateway restart.
   - Restart with:
     ```sh
     launchctl kickstart -k "gui/$(id -u)/ai.openclaw.gateway"
     ```

4. Keep `SOUL.md` language natural, not aggressive.
   - Strong override language can cause models to refuse open-ended questions.
   - If a model ignores persona guidance, the issue is generally the model, not the wording.
