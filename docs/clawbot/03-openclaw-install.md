# 03 - Install OpenClaw (Optional UI + Required Gateway)

OpenClaw is the **only** remote/control surface documented here.

## 1) Install OpenClaw

On the host:

```bash
npm --prefix tools/openclaw install
bin/openclaw status
```

If `openclaw status` fails, inspect:

```bash
ls -la tools/openclaw/node_modules/.bin/openclaw
bin/openclaw --help | head
```

## 2) Where OpenClaw Stores Config

OpenClaw config typically lives at:

- `~/.openclaw/openclaw.json`

If you're hunting for the gateway auth token later, that's the first place to check.

## 3) systemd User Services and PATH Gotchas

If you run OpenClaw under a **systemd user service**, the service may not inherit the same PATH as your interactive shell.

To avoid PATH problems in systemd:

- Prefer an absolute path to the repo-local OpenClaw binary in `ExecStart`, e.g.:
  - `%h/cicero/bin/openclaw ...`

You'll validate this in `docs/clawbot/04-openclaw-gateway.md`.
