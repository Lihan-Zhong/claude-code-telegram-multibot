**🇺🇸English** · [🇨🇳中文](README.zh.md)

# claude-code-telegram-multibot

One dedicated Telegram bot per Claude Code project · independent state · zero cross-talk

> **TL;DR** — pair the official [`telegram plugin`](https://github.com/anthropics/claude-plugins-official) with a few shell functions and a Claude Code skill, so each project directory gets its own Telegram bot. Switch projects in Telegram by switching chats, not terminals.
>
> However, this skill is certainly not only applicable to **Claude code**; it can certainly be directly migrated to **other agent platforms** such as **Codex/OpenClaw**. The skills and of course, of course, not only can be used for deployment of **Telegram**, it can also directly to WhatsAPP/Slack/Discord/QQ/WeChat iMessages /... It's waiting for everyone to develop together!

## ✨ Why

The official Telegram plugin assumes **one bot per user**. If you want multiple Claude Code projects each bridged to a different Telegram chat, the default setup runs into two walls:

- Every `claude` invocation spawns the plugin's MCP server, which uses a stale-PID killer to claim the singleton state directory. Each new session silently disconnects the previous one.
- The `/telegram:access` skill hardcodes the default state directory, so per-project pairing workflows fail.

The trick: the plugin's `server.ts` honors a `TELEGRAM_STATE_DIR` environment variable. Point it at a unique directory per project and you get full isolation — separate token, separate pairing, separate bot server, no fighting.

The shell functions in `claude-tg.bash` derive `TELEGRAM_STATE_DIR` from `basename "$PWD"`, so launching `claude-tg` in any project directory automatically targets that project's own bot. The companion skill (`SKILL.md`) teaches Claude Code agents the architecture, so saying *"add a new Telegram bot for this project"* becomes a one-shot operation.

## 🚀 Quick start

> Prereqs: Claude Code installed · official `telegram` plugin enabled · `bun` on `$PATH` · org policy permits channels · Telegram account.

```bash
# 1. Install
git clone https://github.com/Lihan-Zhong/claude-code-telegram-multibot.git
cd claude-code-telegram-multibot

# 2. Load the shell functions
echo "source $PWD/claude-tg.bash" >> ~/.bashrc
source ~/.bashrc

# 3. Install the skill (teaches Claude Code to manage the setup)
mkdir -p ~/.claude/skills/setup-telegram-multibot
cp SKILL.md ~/.claude/skills/setup-telegram-multibot/SKILL.md
```

Add a bot for a project:

```bash
cd /path/to/my-project           # whatever project
claude-tg-init                   # paste the @BotFather token; writes a .env
claude-tg                        # launch Claude Code with this bot attached

# In Telegram: DM your new bot any plain message (NOT /start).
# Bot replies with a 6-char pair code.
claude-tg-pair <6-char-code>     # if jq is installed
# Or in the Claude Code session: "I got the pair code, please pair me."
```

Done. Future `cd /path/to/my-project && claude-tg` re-attaches to the same bot.

## 🚀 Much easier Quick start

```bash
# 1. Install
git clone https://github.com/Lihan-Zhong/claude-code-telegram-multibot.git
cd claude-code-telegram-multibot
```

Then, ask your claude code to read this whole repo, and then it will know everything about how to do 🔥!

## 💼 Recommended Usage

- Step 1, use this method to deploy`your first Telegram chatting window`, connect`your first Claude code terminal`(Manager)
- Step 2, use`your first Telegram chatting window`you just deployed, to deploy the following Claude code terminal (workers)
- Then, you will have plenty of workhorses~

## 📁 What's in this repo

- `claude-tg.bash` — four shell functions: `claude-tg`, `claude-tg-init`, `claude-tg-alt`, `claude-tg-pair`. Source from `~/.bashrc`.
- `SKILL.md` — Claude Code skill that teaches an agent the architecture. Drop into `~/.claude/skills/setup-telegram-multibot/SKILL.md`.
- `README.md` / `README.zh.md` — this file (English / 中文).
- `LICENSE` — MIT.
- `.gitignore` — keeps tokens and state dirs out of git by default.

## 🧩 Two bots in the same project (alt mode)

Want two independent Claude Code sessions on the same project — a "primary" run and a "what if I tried it this way" experiment? Use `claude-tg-alt`:

```bash
cd /path/to/my-project

# After setting up the primary bot:
mkdir -p ~/.claude-telegram/$(basename "$PWD")-2
$EDITOR ~/.claude-telegram/$(basename "$PWD")-2/.env   # paste a second bot's token

claude-tg-alt        # variant 2 by default
claude-tg-alt 3      # variant 3, if you want a third
```

`claude-tg-alt` also exports `CLAUDE_BOT_VARIANT=N`, so your project rules can pick a variant-specific sandbox directory:

```bash
# in your CLAUDE.md or project rules
SANDBOX="Intermediate_data/for_claude${CLAUDE_BOT_VARIANT:+_${CLAUDE_BOT_VARIANT}}"
```

Bot A writes to `Intermediate_data/for_claude/`, bot A-alt writes to `Intermediate_data/for_claude_2/`. No collisions.

## 🗂️ State directory layout

```
~/.claude-telegram/
├── <user>/                    # optional: symlink → ~/.claude/channels/telegram
├── <project-A-basename>/
│   ├── .env                   # TELEGRAM_BOT_TOKEN=...        (chmod 600)
│   ├── access.json            # dmPolicy / allowFrom / pending (chmod 600)
│   ├── bot.pid                # current bot server PID
│   ├── approved/<senderId>    # pairing-confirm signal files
│   └── inbox/                 # received attachments (photos etc.)
├── <project-A-basename>-2/    # alt bot for project A
└── <project-B-basename>/
    └── ...
```

If you already had the single-default-bot setup working, preserve it for your `$HOME` directory:

```bash
mkdir -p ~/.claude-telegram
ln -s ~/.claude/channels/telegram ~/.claude-telegram/$(basename "$HOME")
```

`cd ~ && claude-tg` then routes to the existing bot with no file migration.

## 🐛 Known issues

> See [`SKILL.md`](SKILL.md) for the full troubleshooting catalogue.

- **`/start` silently fails.** Send a plain DM instead (`hi`, `test`). The plugin's `/start` handler has a known reply-delivery bug. But totally no worries about this, you just need to send `any messages` to the telegram chatbox, that will work!
- **`/telegram:access pair` reports "code not found".** The official skill hardcodes `~/.claude/channels/telegram/access.json` and ignores `TELEGRAM_STATE_DIR`. Use `claude-tg-pair` from this repo, or follow the manual file-edit path in SKILL.md.
- **MCP "failed — Skipping connection" cached.** Run `/doctor` then `/mcp` inside Claude Code. `/mcp` offers a manual retry. Usually a transient PID race on startup; second attempt succeeds.
- **`stop_reason: refusal` mid-session.** Anthropic's safety classifier can false-positive on bloated sessions. Recovery: `/exit` then `claude-tg` (**no `-c`/`-r`** — those resume the poisoned session). Rebuild context from project files. Mitigation: keep tool outputs small, write big results to files instead of pasting them through the agent.
- **HPC: `bot.pid` seems dead but Telegram still routes.** The bot server may be on a different compute node; PID numbers don't translate across nodes. Trust `access.json` and `approved/` over `ps -p <pid>`.

## 🔒 Security notes

- Bot tokens grant full control of the bot. `.env` files are `chmod 600` inside `chmod 700` directories. Don't commit them, don't paste them in shared chats. The included `.gitignore` excludes `.env`, `*.env`, `.claude-telegram/`, `.claude/channels/`.
- `allowFrom` is the only gate to a Claude Code session behind a bot. Anyone whose Telegram numeric user_id is listed can effectively type into the paired session. Treat the list as carefully as shell access.
- The plugin sends outbound traffic only to `api.telegram.org`. No third-party endpoints.

## 🤝 Contributing

PRs welcome, especially:

- A native `/start` reply fix (upstream PR to `claude-plugins-official`).
- Variant-aware `claude-tg-pair` (currently only handles the primary bot's state dir).
- A sister `claude-code-discord-multibot` adaptation — Discord has an official plugin with the same architecture and would benefit from the same workaround.

## 📜 License

MIT — see [`LICENSE`](LICENSE).