#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OPENCLAW_DIR="$HOME/.openclaw"

info()  { printf '\033[1;34m[INFO]\033[0m  %s\n' "$*"; }
error() { printf '\033[1;31m[ERROR]\033[0m %s\n' "$*"; exit 1; }

main() {
    info "=== ClawOps Deploy ==="

    # Load secrets
    if [ ! -f "$REPO_DIR/.env" ]; then
        error ".env not found — run 'cp .env.example .env' and fill in your secrets."
    fi
    set -a
    source "$REPO_DIR/.env"
    set +a

    # Copy static config
    mkdir -p "$OPENCLAW_DIR"
    cp "$REPO_DIR/openclaw.json" "$OPENCLAW_DIR/openclaw.json"
    info "Config copied to $OPENCLAW_DIR/openclaw.json"

    # Inject gateway token via openclaw CLI
    openclaw config set gateway.auth.token "${OPENCLAW_GATEWAY_TOKEN}"
    info "Gateway token injected"
    # Note: TELEGRAM_BOT_TOKEN is read from env by the Telegram plugin at runtime

    # Enable Qwen Portal OAuth plugin (idempotent)
    openclaw plugins enable qwen-portal-auth 2>/dev/null || true
    info "Qwen Portal Auth plugin enabled"

    # Sync service files (no restart)
    if [ "$(uname -s)" = "Linux" ]; then
        if [ "$(id -u)" -eq 0 ]; then
            info "Syncing systemd service files..."
            cp "$REPO_DIR/systemd/openclaw-gateway.service" /etc/systemd/system/
            cp "$REPO_DIR/systemd/ollama.service" /etc/systemd/system/
            systemctl daemon-reload
            info "Service files synced (run 'make restart' to apply)"
        else
            info "Run as root to sync systemd services: sudo bash $0"
        fi
    elif [ "$(uname -s)" = "Darwin" ]; then
        info "Syncing LaunchAgents..."
        mkdir -p "$HOME/Library/LaunchAgents"
        for plist in "$REPO_DIR"/launchd/*.plist; do
            sed -e "s|{{HOME}}|$HOME|g" \
                -e "s|{{USER}}|$(whoami)|g" \
                -e "s|{{REPO_DIR}}|$REPO_DIR|g" \
                "$plist" > "$HOME/Library/LaunchAgents/$(basename "$plist")"
        done
        info "LaunchAgents synced (run 'make restart' to apply)"
    fi

    info "=== Deploy complete ==="
}

main "$@"
