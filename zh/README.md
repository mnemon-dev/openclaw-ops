# OpenClaw Ops

[English](../README.md) | [中文](README.md)

[OpenClaw](https://github.com/mnemon-dev/openclaw) 多模型 AI 网关的一键部署工具。克隆、配置、`make deploy && make start` 即可运行。

支持 macOS (launchd) 和 Linux (systemd)。

## 架构

```
                                    ┌──▶ CLIProxyAPI (:3456) ────────┐
Telegram / WebChat ──▶ OpenClaw ──▶─┼──▶ claude-max-api-proxy (:3457)├──▶ Anthropic (OAuth)
   Gateway (:18789)                 └──▶ Qwen Portal ──▶ portal.qwen.ai (OAuth)
```

| 组件 | 说明 |
|------|------|
| **OpenClaw Gateway** | AI 网关，提供 WebChat、Telegram 等渠道，支持 `/model` 切换 |
| **CLIProxyAPI** | Claude Max/Pro 代理，Anthropic Messages 格式 (Go, brew 安装) |
| **claude-max-api-proxy** | Claude Max/Pro 代理，OpenAI Completions 格式 (Node.js) |
| **Qwen Portal** | 通义千问免费 OAuth 接入 (coder-model / vision-model) |

> 两个 Claude proxy 后端走同一个 Max/Pro 订阅，互为备份。

## 前置条件

```bash
# macOS
brew install cliproxyapi        # Claude API 代理 (anthropic-messages)
npm install -g openclaw@latest   # OpenClaw 网关

# claude-max-api-proxy (openai-completions)
git clone https://github.com/mnemon-dev/claude-max-api-proxy.git ~/.claude-max-api-proxy
cd ~/.claude-max-api-proxy && npm install && npm run build

# 首次登录
cliproxyapi -claude-login        # CLIProxyAPI OAuth 登录
claude auth login                # claude-max-api-proxy 认证
openclaw plugins enable qwen-portal-auth          # (可选) 启用 Qwen Portal
openclaw models auth login --provider qwen-portal  # (可选) Qwen Portal 登录
```

## 快速开始

```bash
git clone https://github.com/mnemon-dev/openclaw-ops.git
cd openclaw-ops

# 1. 配置 secrets
cp .env.example .env
vim .env                         # 填入 TELEGRAM_BOT_TOKEN、OPENCLAW_GATEWAY_TOKEN

# 2. 配置网关
cp openclaw.example.json openclaw.json
vim openclaw.json                # 按需修改 (token 由 deploy 自动注入)

# 3. 部署 + 启动
make deploy
make start

# 4. 验证
make status
curl --noproxy '*' -s http://127.0.0.1:3456/v1/models   # CLIProxyAPI
curl --noproxy '*' -s http://127.0.0.1:3457/v1/models   # claude-max-api-proxy
open http://127.0.0.1:18789                               # WebChat
```

## Make 命令

| 命令 | 说明 |
|------|------|
| `make deploy` | 同步配置 + 注入 token (不重启) |
| `make start` | 启动所有服务 |
| `make stop` | 停止所有服务 |
| `make restart` | 重启所有服务 |
| `make status` | 查看服务状态 |
| `make dev` | 前台开发模式 (Ctrl+C 停止) |
| `make logs` | Gateway 日志 |
| `make logs-proxy` | CLIProxyAPI 日志 |
| `make logs-max` | claude-max-api-proxy 日志 |
| `make backup` | 备份 OpenClaw 状态 |
| `make restore FILE=...` | 从备份恢复 |
| `make deploy-memory` | 安装 [mnemon](https://github.com/mnemon-dev/mnemon) 跨会话记忆 |

## 配置

项目使用两个配置文件，职责分离：

| 文件 | 用途 | 是否提交 |
|------|------|----------|
| `.env` | Secrets (gateway token, Telegram token) | 否 (.gitignore) |
| `openclaw.json` | 模型定义、端口等静态配置 | 否 (.gitignore) |
| `.env.example` | Secrets 模板 | 是 |
| `openclaw.example.json` | 配置模板 | 是 |

`make deploy` 会将 `openclaw.json` 复制到 `~/.openclaw/` 并通过 `openclaw config set` 注入 token。macOS 上还会将 `launchd/*.plist` 模板渲染后安装到 `~/Library/LaunchAgents/`。

CLIProxyAPI 配置位于 `/opt/homebrew/etc/cliproxyapi.conf` (brew 管理)。

```bash
# 修改配置后
vim openclaw.json   # 或 vim .env
make deploy && make restart
```

## 模型切换

在 WebChat 或 Telegram 中使用 `/model <别名>` 切换：

| 别名 | 模型 | 后端 |
|------|------|------|
| `opus` | Claude Opus 4.6 | CLIProxyAPI |
| `sonnet` | Claude Sonnet 4.6 | CLIProxyAPI |
| `haiku` | Claude Haiku 4.5 | CLIProxyAPI |
| `max-opus` | Claude Opus 4 | claude-max-api-proxy |
| `max-sonnet` | Claude Sonnet 4 | claude-max-api-proxy |
| `max-haiku` | Claude Haiku 4 | claude-max-api-proxy |
| `qwen-coder` | Qwen Coder | Qwen Portal |
| `qwen-vision` | Qwen Vision | Qwen Portal |

## 跨会话记忆 (mnemon)

[mnemon](https://github.com/mnemon-dev/mnemon) 为 OpenClaw 提供跨会话持久记忆。AI 对话中积累的重要信息会自动存储，后续会话中按需召回。

```bash
make deploy-memory   # 安装 mnemon + 部署到 OpenClaw
make restart         # 重启生效
```

启用后，记忆通过四个生命周期钩子透明运作：

| 钩子 | 作用 |
|------|------|
| **Prime** | 会话开始时加载行为指南 |
| **Remind** | 工作前自动召回相关记忆 |
| **Nudge** | 工作后提示保存重要信息 |
| **Compact** | 上下文压缩前提取洞察 |

## 目录结构

```
openclaw-ops/
├── .env.example              # Secrets 模板
├── openclaw.example.json     # 网关配置模板
├── Makefile                  # 所有操作入口
├── launchd/                  # macOS plist 模板 (部署时自动渲染)
├── systemd/                  # Linux systemd service
└── scripts/
    ├── deploy.sh             # 同步配置 + 注入 token
    ├── deploy-memory.sh      # 安装 mnemon
    ├── dev.sh                # 前台开发模式
    ├── start-gateway.sh      # Gateway 启动脚本
    ├── start-claude-max.sh   # claude-max-api-proxy 启动脚本
    ├── backup.sh             # 备份
    └── restore.sh            # 恢复

~/.openclaw/                  # 运行时目录 (deploy 自动生成)
├── openclaw.json             # 运行时配置 (含注入的 token)
└── sessions/                 # 会话数据
```

## 故障排查

```bash
# 查看日志
make logs          # Gateway
make logs-proxy    # CLIProxyAPI
make logs-max      # claude-max-api-proxy

# 测试连通性 (本地需加 --noproxy '*' 绕过系统代理)
curl --noproxy '*' -s http://127.0.0.1:3456/health
curl --noproxy '*' -s http://127.0.0.1:3457/health

# 清理残留进程
make stop
ps aux | grep -E "openclaw|cliproxyapi|claude-max" | grep -v grep

# 重新登录
cliproxyapi -claude-login     # CLIProxyAPI 重新 OAuth
claude auth login             # claude-max-api-proxy 重新认证
```

<details>
<summary>日志路径 (macOS)</summary>

| 服务 | stdout | stderr |
|------|--------|--------|
| Gateway | `/tmp/openclaw-gateway.stdout.log` | `/tmp/openclaw-gateway.stderr.log` |
| CLIProxyAPI | `/tmp/cliproxyapi.stdout.log` | `/tmp/cliproxyapi.stderr.log` |
| claude-max | `/tmp/claude-max-api.stdout.log` | `/tmp/claude-max-api.stderr.log` |

</details>

## License

[MIT](../LICENSE)
