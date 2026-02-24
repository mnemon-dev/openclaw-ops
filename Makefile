SHELL := /bin/bash
REPO_DIR := $(shell pwd)
OS := $(shell uname -s)

.PHONY: deploy deploy-memory start stop restart status logs logs-proxy logs-max dev backup restore help

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-14s\033[0m %s\n", $$1, $$2}'

deploy: ## Sync config and inject secrets (no restart)
	@bash scripts/deploy.sh

deploy-memory: ## Install mnemon and enable memory for OpenClaw
	@bash scripts/deploy-memory.sh

start: ## Start proxy + claude-max + gateway services
ifeq ($(OS),Darwin)
	launchctl load ~/Library/LaunchAgents/ai.openclaw.proxy.plist 2>/dev/null || true
	launchctl load ~/Library/LaunchAgents/ai.openclaw.claude-max.plist 2>/dev/null || true
	launchctl load ~/Library/LaunchAgents/ai.openclaw.gateway.plist 2>/dev/null || true
else
	sudo systemctl start openclaw-proxy openclaw-claude-max openclaw-gateway
endif
	@echo "Proxy + Claude-Max + Gateway started"

stop: ## Stop proxy + claude-max + gateway services
ifeq ($(OS),Darwin)
	launchctl unload ~/Library/LaunchAgents/ai.openclaw.gateway.plist 2>/dev/null || true
	launchctl unload ~/Library/LaunchAgents/ai.openclaw.claude-max.plist 2>/dev/null || true
	launchctl unload ~/Library/LaunchAgents/ai.openclaw.proxy.plist 2>/dev/null || true
else
	sudo systemctl stop openclaw-gateway openclaw-claude-max openclaw-proxy
endif
	@echo "Proxy + Claude-Max + Gateway stopped"

restart: stop start ## Restart proxy + claude-max + gateway services

status: ## Show service status
ifeq ($(OS),Darwin)
	@echo "=== Proxy ===" && launchctl list | grep openclaw.proxy || echo "Proxy not loaded"
	@echo "=== Claude-Max ===" && launchctl list | grep openclaw.claude-max || echo "Claude-Max not loaded"
	@echo "=== Gateway ===" && launchctl list | grep openclaw.gateway || echo "Gateway not loaded"
else
	@sudo systemctl status openclaw-proxy --no-pager -l || true
	@echo "---"
	@sudo systemctl status openclaw-claude-max --no-pager -l || true
	@echo "---"
	@sudo systemctl status openclaw-gateway --no-pager -l || true
endif

logs: ## Show gateway logs
ifeq ($(OS),Darwin)
	@tail -f /tmp/openclaw-gateway.stdout.log /tmp/openclaw-gateway.stderr.log
else
	@sudo journalctl -u openclaw-gateway -f --no-pager
endif

logs-proxy: ## Show CLIProxyAPI logs
ifeq ($(OS),Darwin)
	@tail -f /tmp/cliproxyapi.stdout.log /tmp/cliproxyapi.stderr.log
else
	@sudo journalctl -u openclaw-proxy -f --no-pager
endif

logs-max: ## Show claude-max-api-proxy logs
ifeq ($(OS),Darwin)
	@tail -f /tmp/claude-max-api.stdout.log /tmp/claude-max-api.stderr.log
else
	@sudo journalctl -u openclaw-claude-max -f --no-pager
endif

dev: ## Start proxy + gateway in foreground (development mode)
	@bash scripts/dev.sh

backup: ## Backup OpenClaw state
	@bash scripts/backup.sh

restore: ## Restore from backup (usage: make restore FILE=path/to/backup.tar.gz)
	@bash scripts/restore.sh $(FILE)
