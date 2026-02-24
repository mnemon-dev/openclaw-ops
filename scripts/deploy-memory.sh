#!/usr/bin/env bash
set -euo pipefail

info()  { printf '\033[1;34m[INFO]\033[0m  %s\n' "$*"; }
ok()    { printf '\033[1;32m[OK]\033[0m    %s\n' "$*"; }
error() { printf '\033[1;31m[ERROR]\033[0m %s\n' "$*"; exit 1; }

main() {
    info "=== Deploy Memory (mnemon) ==="

    # 1. Install mnemon via Homebrew
    if command -v mnemon &>/dev/null; then
        ok "mnemon already installed: $(mnemon --version)"
    else
        info "Installing mnemon via Homebrew..."
        if ! command -v brew &>/dev/null; then
            error "Homebrew not found. Install it first: https://brew.sh"
        fi
        brew install mnemon-dev/tap/mnemon
        ok "mnemon installed: $(mnemon --version)"
    fi

    # 2. Setup mnemon for OpenClaw
    info "Setting up mnemon for OpenClaw..."
    mnemon setup --target openclaw --yes
    ok "mnemon hooks and skills deployed to ~/.openclaw/"

    # 3. Remind user to restart
    info "=== Deploy Memory complete ==="
    info "Run 'make restart' to activate mnemon in the gateway."
}

main "$@"
