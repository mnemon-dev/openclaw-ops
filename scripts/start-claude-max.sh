#!/usr/bin/env bash
set -euo pipefail

# Proxy for external traffic (Claude CLI needs proxy to reach Anthropic API)
export http_proxy="${http_proxy:-http://127.0.0.1:6152}"
export https_proxy="${https_proxy:-http://127.0.0.1:6152}"
export all_proxy="${all_proxy:-socks5://127.0.0.1:6153}"
# Bypass proxy for local services
export NO_PROXY="127.0.0.1,localhost"

# Ensure Node 22+ is available (managed by fnm)
if command -v fnm &>/dev/null; then
    eval "$(fnm env)"
    fnm use 22 --silent-if-unchanged 2>/dev/null || true
fi

exec node "$HOME/.claude-max-api-proxy/dist/server/standalone.js" 3457
