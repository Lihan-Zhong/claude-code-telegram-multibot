[🇺🇸English](README.md) · **🇨🇳中文**

# claude-code-telegram-multibot

让 Claude Code 每个项目目录绑定一个独立的 Telegram bot · 互不干扰 · 切项目只需在 Telegram 切聊天

> **太长不看版** —— 把官方 [`telegram 插件`](https://github.com/anthropics/claude-plugins-official) 配上几个 shell 函数和一份 Claude Code skill，让每个项目目录拥有自己的 Telegram bot。切项目只需在 Telegram 里换聊天，不再需要切终端。
>
> 不过，这个skills当然不止可以用于**Claude code**，它当然可以直接迁移到**Codex/Open Claw等其它agent平台**。当然，这个skills也当然不止可以用于**Telegram**的部署，它也可以直接迁移到WhatsAPP/Slack/Discord/QQ/WeChat/iMessages/...有待大家一起开发！

## ✨ 为什么需要它

官方 Telegram 插件默认是 **一用户一 bot**。如果你想让多个 Claude Code 项目各对接一个 Telegram 聊天，会撞上两堵墙：

- 每次 `claude` 启动都会拉起插件的 MCP server，而它的 stale-PID 杀手会霸占共享的 state 目录。每开一个新会话，前一个会被静默断开。
- `/telegram:access` skill 硬编码默认的 state 目录路径，所以"每项目一个 pair 流程"在那里走不通。

关键发现：插件的 `server.ts` 尊重 `TELEGRAM_STATE_DIR` 环境变量。给每个项目指定不同的目录，就得到完整隔离 —— 独立 token、独立 pairing、独立 bot server，互不打架。

`claude-tg.bash` 里的 shell 函数会根据 `basename "$PWD"` 自动派生 `TELEGRAM_STATE_DIR`，所以在任何项目目录里跑 `claude-tg` 自动对接那个项目的 bot。配套的 `SKILL.md` 让 Claude Code agent 懂这套架构，于是 *"给这个项目加个新 Telegram bot"* 变成一句话搞定。

## 🚀 快速开始

> 前置条件：已装 Claude Code · 官方 `telegram` 插件已启用 · `bun` 在 `$PATH` · 组织策略允许 channels · 有 Telegram 账号。

```bash
# 1. 安装
git clone https://github.com/Lihan-Zhong/claude-code-telegram-multibot.git
cd claude-code-telegram-multibot

# 2. 加载 shell 函数
echo "source $PWD/claude-tg.bash" >> ~/.bashrc
source ~/.bashrc

# 3. 安装 skill（让 Claude Code agent 懂这套架构）
mkdir -p ~/.claude/skills/setup-telegram-multibot
cp SKILL.md ~/.claude/skills/setup-telegram-multibot/SKILL.md
```

给某个项目加一个 bot：

```bash
cd /path/to/my-project           # 任意项目
claude-tg-init                   # 粘贴 @BotFather 给的 token，写入 .env
claude-tg                        # 启动 Claude Code，并挂上这个 bot

# 在 Telegram 里：给新 bot 发任意普通消息（不要发 /start）
# bot 会回一个 6 位的 pair 码
claude-tg-pair <6位码>           # 如果装了 jq
# 或在 Claude Code 会话里说："我拿到 pair 码了，帮我配对一下"
```

完成。以后 `cd /path/to/my-project && claude-tg` 自动接到同一个 bot。

## 🚀 更简单的快速开始

```bash
# 1. 安装
git clone https://github.com/Lihan-Zhong/claude-code-telegram-multibot.git
cd claude-code-telegram-multibot
```

然后，打开Claude code，让它直接读整个GitHub仓库。一看就明白🔥！

## ‼️ 推荐的使用用法

- 第一步，用该方法部署`第一个Telegram聊天窗口`，连接`第一个Claude code终端`（主管）
- 第二步，用刚刚部署`第一个Telegram聊天窗口`，来部署后续的项目窗口（员工）
- 然后，你就会有源源不断的干活牛马了～

## 📁 仓库内容

- `claude-tg.bash` —— 四个 shell 函数：`claude-tg`、`claude-tg-init`、`claude-tg-alt`、`claude-tg-pair`。从 `~/.bashrc` source。
- `SKILL.md` —— Claude Code skill，教 agent 掌握这套架构。放到 `~/.claude/skills/setup-telegram-multibot/SKILL.md`。
- `README.md` / `README.zh.md` —— 本文件的英文/中文版。
- `LICENSE` —— MIT。
- `.gitignore` —— 默认排除 token 和 state 目录，避免误提交。

## 🧩 同一项目下开两个 bot（alt 模式）

想在同一项目里跑两个独立 Claude Code 会话 —— 一个"主线"，一个"我换个思路试试"的实验？用 `claude-tg-alt`：

```bash
cd /path/to/my-project

# 主 bot 配好之后：
mkdir -p ~/.claude-telegram/$(basename "$PWD")-2
$EDITOR ~/.claude-telegram/$(basename "$PWD")-2/.env   # 粘第二个 bot 的 token

claude-tg-alt        # 默认变体 2
claude-tg-alt 3      # 想要第三个 bot 就用 3
```

`claude-tg-alt` 还会注入 `CLAUDE_BOT_VARIANT=N` 环境变量，让项目规则可以按变体选不同沙盒目录：

```bash
# 写在 CLAUDE.md 或项目规则文档里
SANDBOX="Intermediate_data/for_claude${CLAUDE_BOT_VARIANT:+_${CLAUDE_BOT_VARIANT}}"
```

主 bot 写到 `Intermediate_data/for_claude/`，alt bot 写到 `Intermediate_data/for_claude_2/`。互不覆盖。

## 🗂️ State 目录结构

```
~/.claude-telegram/
├── <user>/                    # 可选：符号链接 → ~/.claude/channels/telegram
├── <项目-A-basename>/
│   ├── .env                   # TELEGRAM_BOT_TOKEN=...        (chmod 600)
│   ├── access.json            # dmPolicy / allowFrom / pending (chmod 600)
│   ├── bot.pid                # 当前 bot server 的 PID
│   ├── approved/<senderId>    # 配对确认信号文件
│   └── inbox/                 # 收到的附件（图片等）
├── <项目-A-basename>-2/       # 项目 A 的 alt bot
└── <项目-B-basename>/
    └── ...
```

如果你之前已经在用单 bot 默认布局，可以为 `$HOME` 目录保留它：

```bash
mkdir -p ~/.claude-telegram
ln -s ~/.claude/channels/telegram ~/.claude-telegram/$(basename "$HOME")
```

之后 `cd ~ && claude-tg` 自动接到原 bot，不用迁移文件。

## 🐛 已知问题

> 完整排查清单见 [`SKILL.md`](SKILL.md)。

- **`/start` 静默失败。** 改发普通消息（`hi`、`test`）。插件的 `/start` handler 有已知的回复送达问题。但这个问题不需要担心，你只要对Telegram的聊天窗口，发`任意消息`就好了！
- **`/telegram:access pair` 报 "code not found"。** 官方 skill 硬编码 `~/.claude/channels/telegram/access.json`，不尊重 `TELEGRAM_STATE_DIR`。改用本仓库的 `claude-tg-pair`，或按 SKILL.md 走手动文件编辑流程。
- **MCP "failed — Skipping connection" 被缓存。** 在 Claude Code 里跑 `/doctor` 然后 `/mcp`，`/mcp` 提供手动重试。通常是启动时 PID race 的瞬时问题，重试一次就好。
- **会话中途 `stop_reason: refusal`。** Anthropic 安全分类器对体积过大的 session 可能假阳性。恢复方法：`/exit` 后用 `claude-tg`（**不带 `-c`/`-r`**，否则会复活被污染的 session），通过读文件重建上下文。预防：单次 tool 输出控制在小尺寸（`head -5` 而不是 `cat`），大结果落到文件里、引用路径而不是粘贴内容。
- **HPC 多节点：`bot.pid` 看上去死了但 Telegram 还能通。** Bot server 可能在另一个计算节点；PID 数字跨节点没意义。信 `access.json` 和 `approved/`，别盲信 `ps -p <pid>`。

## 🔒 安全提示

- Bot token 等同密码。`.env` 文件 `chmod 600`，外层目录 `chmod 700`。不要提交到 git，不要在群聊里粘贴。仓库的 `.gitignore` 已默认排除 `.env`、`*.env`、`.claude-telegram/`、`.claude/channels/`。
- `allowFrom` 是 bot 背后 Claude Code 会话的唯一访问门槛。任何在列表里的 Telegram numeric user_id 实际上可以"打字"进那个会话。把它当 shell 权限对待。
- 插件只对 `api.telegram.org` 发出站请求，没有第三方 endpoint。

## 🤝 贡献

欢迎 PR，特别想要：

- 修 `/start` 静默失败（最好直接给 `claude-plugins-official` 提 upstream PR）。
- 让 `claude-tg-pair` 支持 alt 变体（目前只能处理主 bot 的 state 目录）。
- 做一个姐妹仓库 `claude-code-discord-multibot` —— Discord 有官方插件且架构相似，同样会受益于这套绕过方案。

## 📜 License

MIT —— 见 [`LICENSE`](LICENSE)。