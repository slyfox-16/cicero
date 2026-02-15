# 03 - Install OpenClaw (Optional UI + Required Gateway)

OpenClaw is the **only** remote/control surface documented here.

## 1) Install OpenClaw

On the host:

```bash
sudo npm install -g openclaw@latest
openclaw status
```

If `openclaw status` fails, inspect:

```bash
which openclaw
openclaw --help | head
```

## 2) Where OpenClaw Stores Config

OpenClaw config typically lives at:

- `~/.openclaw/openclaw.json`

If you're hunting for the gateway auth token later, that's the first place to check.

## 3) systemd User Services and PATH Gotchas

If you run OpenClaw under a **systemd user service**, the service may not inherit the same PATH as your interactive shell.

To avoid PATH problems in systemd:

- Prefer `/usr/bin/env openclaw ...` in `ExecStart`, or
- Use an absolute path from `which openclaw`

You'll validate this in `clawbot/04-openclaw-gateway.md`.

