# claude-tg.bash — Shell functions for the Claude Code multi-bot Telegram setup.
#
# Source this file from your ~/.bashrc (or paste these functions in directly).
#
# Provides:
#   claude-tg              — launch Claude Code with the primary Telegram bot for the current project dir
#   claude-tg-alt [N]      — launch Claude Code with the Nth alt bot (default N=2) in the SAME project dir
#                            (lets you run two independent agents in one project, each with its own bot)
#   claude-tg-init         — interactive: paste a fresh bot token from @BotFather to seed a new project's .env
#   claude-tg-pair <code>  — manually approve a pairing code (alternative to /telegram:access pair).
#                            Requires `jq`. Useful when /telegram:access misroutes because of a custom state dir.
#
# State layout per project (created on first use):
#   ~/.claude-telegram/<basename-of-cwd>/         # primary bot, claude-tg
#   ~/.claude-telegram/<basename-of-cwd>-2/       # alt bot 2, claude-tg-alt
#   ~/.claude-telegram/<basename-of-cwd>-N/       # alt bot N, claude-tg-alt N
#
# Each state dir holds:
#   .env             # TELEGRAM_BOT_TOKEN=...  (chmod 600)
#   access.json      # dmPolicy, allowFrom, pending, groups
#   bot.pid          # current server.ts PID
#   approved/<id>    # one-shot pairing-confirm signals
#
# Requires:
#   - claude (the Claude Code CLI), already in PATH
#   - the `telegram` plugin from anthropics/claude-plugins-official, enabled in ~/.claude/settings.json
#     ("enabledPlugins": { "telegram@claude-plugins-official": true })
#   - org policy allows channels (see Anthropic admin console)
#
# Defensive: remove any stale alias before defining functions (alias would shadow the function definition
# AND cause a syntax error on re-source if a leftover `alias claude-tg=...` is still in the shell's table).
unalias claude-tg 2>/dev/null

claude-tg() {
  local state="$HOME/.claude-telegram/$(basename "$PWD")"
  mkdir -p "$state"
  chmod 700 "$state"
  if [ ! -f "$state/.env" ]; then
    echo "⚠️  $state/.env not found" >&2
    echo "   Create a bot via @BotFather, then run:" >&2
    echo "   claude-tg-init" >&2
    return 1
  fi
  TELEGRAM_STATE_DIR="$state" command claude --channels plugin:telegram@claude-plugins-official "$@"
}

claude-tg-init() {
  local state="$HOME/.claude-telegram/$(basename "$PWD")"
  mkdir -p "$state" && chmod 700 "$state"
  echo "Paste the bot token from @BotFather, then press Enter:"
  read -r token
  printf "TELEGRAM_BOT_TOKEN=%s\n" "$token" > "$state/.env"
  chmod 600 "$state/.env"
  echo "✅ Saved to $state/.env"
  echo "   Now run: claude-tg"
}

claude-tg-alt() {
  # Numeric first arg = variant suffix (e.g. claude-tg-alt 3 -> state dir basename-3).
  # Otherwise default to 2.
  local variant
  if [[ "$1" =~ ^[0-9]+$ ]]; then
    variant="$1"
    shift
  else
    variant="2"
  fi
  local state="$HOME/.claude-telegram/$(basename "$PWD")-${variant}"
  mkdir -p "$state"
  chmod 700 "$state"
  if [ ! -f "$state/.env" ]; then
    echo "⚠️  $state/.env not found" >&2
    echo "   Set up bot #${variant}: write the BotFather token to $state/.env" >&2
    return 1
  fi
  # CLAUDE_BOT_VARIANT lets project rules (e.g. a CLAUDE.md sandbox section) resolve
  # variant-specific working dirs (Intermediate_data/for_claude_<N>/) so alt bots in
  # the same project dir don't collide with the primary bot.
  TELEGRAM_STATE_DIR="$state" CLAUDE_BOT_VARIANT="$variant" command claude --channels plugin:telegram@claude-plugins-official "$@"
}

claude-tg-pair() {
  if [ -z "$1" ]; then
    echo "Usage: claude-tg-pair <6-char-code>" >&2
    echo "Run from the project directory after DMing the bot." >&2
    return 1
  fi
  if ! command -v jq >/dev/null 2>&1; then
    echo "⚠️  jq not installed. Install with one of:" >&2
    echo "   conda install -c conda-forge jq" >&2
    echo "   sudo apt install jq    # Debian/Ubuntu" >&2
    echo "   brew install jq        # macOS" >&2
    return 1
  fi
  local state="$HOME/.claude-telegram/$(basename "$PWD")"
  local acc="$state/access.json"
  local code="$1"
  if [ ! -f "$acc" ]; then
    echo "⚠️  No access.json at $acc" >&2
    echo "   Start claude-tg in this directory first, then DM the bot." >&2
    return 1
  fi
  local sender chat
  sender=$(jq -r --arg c "$code" '.pending[$c].senderId // empty' "$acc")
  chat=$(jq -r --arg c "$code" '.pending[$c].chatId // empty' "$acc")
  if [ -z "$sender" ]; then
    echo "⚠️  Code '$code' not found in pending. Current pending entries:" >&2
    jq '.pending | keys' "$acc" >&2
    return 1
  fi
  local tmp
  tmp=$(mktemp)
  jq --arg s "$sender" --arg c "$code" \
    '.allowFrom = (.allowFrom + [$s] | unique) | del(.pending[$c])' \
    "$acc" > "$tmp" && mv "$tmp" "$acc" && chmod 600 "$acc"
  mkdir -p "$state/approved"
  printf '%s' "$chat" > "$state/approved/$sender"
  echo "✅ Paired sender $sender in $(basename "$state")"
}
