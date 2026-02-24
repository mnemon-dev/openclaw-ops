#!/usr/bin/env bash
set -euo pipefail

OPENCLAW_DIR="$HOME/.openclaw"

info()  { printf '\033[1;34m[INFO]\033[0m  %s\n' "$*"; }
warn()  { printf '\033[1;33m[WARN]\033[0m  %s\n' "$*"; }
error() { printf '\033[1;31m[ERROR]\033[0m %s\n' "$*"; exit 1; }

main() {
    info "=== ClawOps Restore ==="

    local backup_file="${1:-}"
    if [ -z "$backup_file" ]; then
        error "Usage: $0 <backup-file.tar.gz>"
    fi

    if [ ! -f "$backup_file" ]; then
        error "Backup file not found: $backup_file"
    fi

    if [ -d "$OPENCLAW_DIR" ]; then
        warn "Existing $OPENCLAW_DIR will be overwritten"
        printf "Continue? [y/N] "
        read -r confirm
        if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
            info "Restore cancelled"
            exit 0
        fi
    fi

    info "Restoring from $backup_file..."
    tar -xzf "$backup_file" -C "$HOME"

    # Restart services
    if [ "$(uname -s)" = "Linux" ]; then
        if command -v systemctl &>/dev/null && systemctl is-active --quiet openclaw-gateway 2>/dev/null; then
            info "Restarting openclaw-gateway service..."
            sudo systemctl restart openclaw-gateway
        fi
    elif [ "$(uname -s)" = "Darwin" ]; then
        local plist="$HOME/Library/LaunchAgents/ai.openclaw.gateway.plist"
        if [ -f "$plist" ]; then
            info "Restarting LaunchAgent..."
            launchctl unload "$plist" 2>/dev/null || true
            launchctl load "$plist"
        fi
    fi

    info "=== Restore complete ==="
}

main "$@"
