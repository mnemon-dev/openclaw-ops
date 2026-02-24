#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OPENCLAW_DIR="$HOME/.openclaw"

info()  { printf '\033[1;34m[INFO]\033[0m  %s\n' "$*"; }
warn()  { printf '\033[1;33m[WARN]\033[0m  %s\n' "$*"; }
error() { printf '\033[1;31m[ERROR]\033[0m %s\n' "$*"; exit 1; }

# --- Pre-flight checks ---

# Ensure Node 22+ is available (OpenClaw requires Node >= 22.12.0)
if command -v fnm &>/dev/null; then
    eval "$(fnm env)"
    fnm use 22 --silent-if-unchanged 2>/dev/null || true
fi

if [ ! -f "$REPO_DIR/.env" ]; then
    error ".env not found. Run 'cp .env.example .env' and fill in your secrets."
fi

if ! command -v cliproxyapi &>/dev/null; then
    error "cliproxyapi not found. Install it via: brew install cliproxyapi"
fi

# --- Stop launchd services if loaded (avoid port conflicts) ---

if [ "$(uname -s)" = "Darwin" ]; then
    if launchctl list 2>/dev/null | grep -q 'ai.openclaw.gateway'; then
        warn "Stopping launchd gateway service (conflicts with dev mode)..."
        launchctl unload ~/Library/LaunchAgents/ai.openclaw.gateway.plist 2>/dev/null || true
    fi
    if launchctl list 2>/dev/null | grep -q 'ai.openclaw.claude-max'; then
        warn "Stopping launchd claude-max service (conflicts with dev mode)..."
        launchctl unload ~/Library/LaunchAgents/ai.openclaw.claude-max.plist 2>/dev/null || true
    fi
    if launchctl list 2>/dev/null | grep -q 'ai.openclaw.proxy'; then
        warn "Stopping launchd proxy service (conflicts with dev mode)..."
        launchctl unload ~/Library/LaunchAgents/ai.openclaw.proxy.plist 2>/dev/null || true
    fi
    sleep 1
fi

# --- Cleanup trap ---

PROXY_PID=""
CLAUDE_MAX_PID=""

cleanup() {
    echo ""
    info "Shutting down..."
    if [ -n "$CLAUDE_MAX_PID" ]; then
        kill "$CLAUDE_MAX_PID" 2>/dev/null || true
        wait "$CLAUDE_MAX_PID" 2>/dev/null || true
        info "claude-max-api-proxy stopped (pid $CLAUDE_MAX_PID)"
    fi
    if [ -n "$PROXY_PID" ]; then
        kill "$PROXY_PID" 2>/dev/null || true
        wait "$PROXY_PID" 2>/dev/null || true
        info "CLIProxyAPI stopped (pid $PROXY_PID)"
    fi
}
trap cleanup EXIT INT TERM

# --- Deploy config + inject secrets ---

info "Deploying config..."
bash "$REPO_DIR/scripts/deploy.sh" 2>&1 | grep -v '=== \|LaunchAgent\|systemd\|Reloading\|Syncing Launch'

# --- Start CLIProxyAPI (background) ---

info "Starting CLIProxyAPI..."
cliproxyapi &
PROXY_PID=$!
sleep 1

if ! kill -0 "$PROXY_PID" 2>/dev/null; then
    error "CLIProxyAPI failed to start"
fi
info "CLIProxyAPI running (pid $PROXY_PID)"

# --- Start claude-max-api-proxy (background) ---

info "Starting claude-max-api-proxy..."
bash "$REPO_DIR/scripts/start-claude-max.sh" &
CLAUDE_MAX_PID=$!
sleep 1

if ! kill -0 "$CLAUDE_MAX_PID" 2>/dev/null; then
    error "claude-max-api-proxy failed to start"
fi
info "claude-max-api-proxy running (pid $CLAUDE_MAX_PID)"

# --- Start gateway (foreground) ---

info "Starting gateway..."
bash "$REPO_DIR/scripts/start-gateway.sh"
