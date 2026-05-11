# Mac Deploy

Migration target. To be written when Cicero moves from Saturn to a Mac mini.

Will mirror `deploy/saturn/setup.sh` but use:

- Homebrew for OpenClaw + Ollama install
- A launchd plist (`~/Library/LaunchAgents/ai.openclaw.gateway.plist`) instead of a systemd unit
- Apple-specific channel enablement (iMessage via BlueBubbles or native bridge)
- Workspace symlink in the same shape: `~/.openclaw/workspace -> <repo>/workspace`

See `docs/roadmap.md` for the migration plan.
