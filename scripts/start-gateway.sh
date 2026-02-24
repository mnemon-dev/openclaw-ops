#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$REPO_DIR/.env"

# Ensure Node 22+ is available (OpenClaw requires Node >= 22.12.0)
if command -v fnm &>/dev/null; then
    eval "$(fnm env)"
    fnm use 22 --silent-if-unchanged 2>/dev/null || true
fi

# Load secrets (TELEGRAM_BOT_TOKEN is read by the Telegram plugin from env)
if [ -f "$ENV_FILE" ]; then
    set -a
    source "$ENV_FILE"
    set +a
fi

# Proxy for external traffic (Telegram API, etc.)
export http_proxy="${http_proxy:-http://127.0.0.1:6152}"
export https_proxy="${https_proxy:-http://127.0.0.1:6152}"
# Bypass proxy for local CLIProxyAPI
export NO_PROXY="127.0.0.1,localhost"

exec /opt/homebrew/bin/openclaw gateway
