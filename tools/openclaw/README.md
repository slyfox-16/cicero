# OpenClaw (Repo-Local)

Install OpenClaw locally under `tools/openclaw/` so it doesn’t depend on a global `npm -g` install.

Pinned dependency:

- `tools/openclaw/package.json`

From repo root:

```bash
npm --prefix tools/openclaw install
bin/openclaw --help | head
bin/openclaw status
```

Note: generating `tools/openclaw/package-lock.json` requires access to the npm registry.

If you need a systemd user service, prefer an **absolute** `ExecStart` that points at:

- `%h/cicero/bin/openclaw` (recommended)
