# OpenClaw Ops

[English](README.md) | [中文](zh/README.md)

One-command deployment toolkit for the [OpenClaw](https://github.com/mnemon-dev/openclaw) multi-model AI gateway. Clone, configure, `make deploy && make start`.

Supports macOS (launchd) and Linux (systemd).

## Architecture

```
                                    ┌──▶ CLIProxyAPI (:3456) ────────┐
Telegram / WebChat ──▶ OpenClaw ──▶─┼──▶ claude-max-api-proxy (:3457)├──▶ Anthropic (OAuth)
   Gateway (:18789)                 └──▶ Qwen Portal ──▶ portal.qwen.ai (OAuth)
```

| Component | Description |
|-----------|-------------|
| **OpenClaw Gateway** | AI gateway with WebChat, Telegram channels and `/model` switching |
| **CLIProxyAPI** | Claude Max/Pro proxy, Anthropic Messages format (Go, brew) |
| **claude-max-api-proxy** | Claude Max/Pro proxy, OpenAI Completions format (Node.js) |
| **Qwen Portal** | Free Qwen OAuth access (coder-model / vision-model) |

> Both Claude proxy backends share the same Max/Pro subscription and serve as fallbacks for each other.

### About claude-max-api-proxy

claude-max-api-proxy works by spawning the official Claude Code CLI locally to handle each request. Since the CLI runs in its own isolated environment, OpenClaw-installed skills and plugins are not available through this backend. On the other hand, all traffic flows through the native CLI and is indistinguishable from normal Claude Code usage.

## Prerequisites

```bash
# macOS
brew install cliproxyapi        # Claude API proxy (anthropic-messages)
npm install -g openclaw@latest   # OpenClaw gateway

# claude-max-api-proxy (openai-completions)
git clone https://github.com/mnemon-dev/claude-max-api-proxy.git ~/.claude-max-api-proxy
cd ~/.claude-max-api-proxy && npm install && npm run build

# First-time login
cliproxyapi -claude-login        # CLIProxyAPI OAuth login
claude auth login                # claude-max-api-proxy auth
openclaw plugins enable qwen-portal-auth          # (optional) enable Qwen Portal
openclaw models auth login --provider qwen-portal  # (optional) Qwen Portal login
```

## Quick Start

```bash
git clone https://github.com/mnemon-dev/openclaw-ops.git
cd openclaw-ops

# 1. Configure secrets
cp .env.example .env
vim .env                         # Set TELEGRAM_BOT_TOKEN, OPENCLAW_GATEWAY_TOKEN

# 2. Configure gateway
cp openclaw.example.json openclaw.json
vim openclaw.json                # Customize as needed (tokens injected by deploy)

# 3. Deploy & start
make deploy
make start

# 4. Verify
make status
curl --noproxy '*' -s http://127.0.0.1:3456/v1/models   # CLIProxyAPI
curl --noproxy '*' -s http://127.0.0.1:3457/v1/models   # claude-max-api-proxy
open http://127.0.0.1:18789                               # WebChat
```

## Make Commands

| Command | Description |
|---------|-------------|
| `make deploy` | Sync config & inject tokens (no restart) |
| `make start` | Start all services |
| `make stop` | Stop all services |
| `make restart` | Restart all services |
| `make status` | Show service status |
| `make dev` | Foreground dev mode (Ctrl+C to stop) |
| `make logs` | Gateway logs |
| `make logs-proxy` | CLIProxyAPI logs |
| `make logs-max` | claude-max-api-proxy logs |
| `make backup` | Backup OpenClaw state |
| `make restore FILE=...` | Restore from backup |
| `make deploy-memory` | Install [mnemon](https://github.com/mnemon-dev/mnemon) cross-session memory |

## Configuration

The project separates config into two files:

| File | Purpose | Committed |
|------|---------|-----------|
| `.env` | Secrets (gateway token, Telegram token) | No (.gitignore) |
| `openclaw.json` | Model definitions, ports, static config | No (.gitignore) |
| `.env.example` | Secrets template | Yes |
| `openclaw.example.json` | Config template | Yes |

`make deploy` copies `openclaw.json` to `~/.openclaw/` and injects tokens via `openclaw config set`. On macOS it also renders `launchd/*.plist` templates and installs them to `~/Library/LaunchAgents/`.

CLIProxyAPI config lives at `/opt/homebrew/etc/cliproxyapi.conf` (managed by brew).

```bash
# After editing config
vim openclaw.json   # or vim .env
make deploy && make restart
```

## Model Switching

Use `/model <alias>` in WebChat or Telegram:

| Alias | Model | Backend |
|-------|-------|---------|
| `opus` | Claude Opus 4.6 | CLIProxyAPI |
| `sonnet` | Claude Sonnet 4.6 | CLIProxyAPI |
| `haiku` | Claude Haiku 4.5 | CLIProxyAPI |
| `max-opus` | Claude Opus 4 | claude-max-api-proxy |
| `max-sonnet` | Claude Sonnet 4 | claude-max-api-proxy |
| `max-haiku` | Claude Haiku 4 | claude-max-api-proxy |
| `qwen-coder` | Qwen Coder | Qwen Portal |
| `qwen-vision` | Qwen Vision | Qwen Portal |

## Cross-Session Memory (mnemon)

[mnemon](https://github.com/mnemon-dev/mnemon) gives OpenClaw persistent cross-session memory. Important information from conversations is automatically stored and recalled in future sessions.

```bash
make deploy-memory   # Install mnemon & deploy to OpenClaw
make restart         # Restart to activate
```

Once enabled, memory operates transparently through four lifecycle hooks:

| Hook | Purpose |
|------|---------|
| **Prime** | Load behavioral guidelines at session start |
| **Remind** | Recall relevant memories before work |
| **Nudge** | Prompt to save important info after work |
| **Compact** | Extract insights before context compaction |

## Directory Structure

```
openclaw-ops/
├── .env.example              # Secrets template
├── openclaw.example.json     # Gateway config template
├── Makefile                  # All operations entry point
├── launchd/                  # macOS plist templates (rendered at deploy time)
├── systemd/                  # Linux systemd services
└── scripts/
    ├── deploy.sh             # Sync config & inject tokens
    ├── deploy-memory.sh      # Install mnemon
    ├── dev.sh                # Foreground dev mode
    ├── start-gateway.sh      # Gateway startup wrapper
    ├── start-claude-max.sh   # claude-max-api-proxy startup wrapper
    ├── backup.sh             # Backup
    └── restore.sh            # Restore

~/.openclaw/                  # Runtime directory (created by deploy)
├── openclaw.json             # Runtime config (with injected tokens)
└── sessions/                 # Session data
```

## Troubleshooting

```bash
# View logs
make logs          # Gateway
make logs-proxy    # CLIProxyAPI
make logs-max      # claude-max-api-proxy

# Test connectivity (add --noproxy '*' to bypass system proxy)
curl --noproxy '*' -s http://127.0.0.1:3456/health
curl --noproxy '*' -s http://127.0.0.1:3457/health

# Clean up stale processes
make stop
ps aux | grep -E "openclaw|cliproxyapi|claude-max" | grep -v grep

# Re-authenticate
cliproxyapi -claude-login     # CLIProxyAPI re-login
claude auth login             # claude-max-api-proxy re-auth
```

<details>
<summary>Log paths (macOS)</summary>

| Service | stdout | stderr |
|---------|--------|--------|
| Gateway | `/tmp/openclaw-gateway.stdout.log` | `/tmp/openclaw-gateway.stderr.log` |
| CLIProxyAPI | `/tmp/cliproxyapi.stdout.log` | `/tmp/cliproxyapi.stderr.log` |
| claude-max | `/tmp/claude-max-api.stdout.log` | `/tmp/claude-max-api.stderr.log` |

</details>

## License

[MIT](LICENSE)
