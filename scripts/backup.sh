#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OPENCLAW_DIR="$HOME/.openclaw"
BACKUP_DIR="$REPO_DIR/backups"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP_FILE="$BACKUP_DIR/openclaw-backup-${TIMESTAMP}.tar.gz"

info()  { printf '\033[1;34m[INFO]\033[0m  %s\n' "$*"; }
error() { printf '\033[1;31m[ERROR]\033[0m %s\n' "$*"; exit 1; }

main() {
    info "=== ClawOps Backup ==="

    if [ ! -d "$OPENCLAW_DIR" ]; then
        error "OpenClaw directory not found: $OPENCLAW_DIR"
    fi

    mkdir -p "$BACKUP_DIR"

    info "Backing up $OPENCLAW_DIR..."
    tar -czf "$BACKUP_FILE" \
        --exclude='node_modules' \
        --exclude='.cache' \
        --exclude='*.tmp' \
        -C "$HOME" \
        ".openclaw"

    local size
    size=$(du -h "$BACKUP_FILE" | cut -f1)
    info "Backup created: $BACKUP_FILE ($size)"
    info "=== Backup complete ==="
}

main "$@"
