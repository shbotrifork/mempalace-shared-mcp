#!/bin/bash
# MEMPALACE PRE-COMPACT HOOK — Emergency save before compaction
#
# Claude Code "PreCompact" hook. Fires RIGHT BEFORE the conversation
# gets compressed to free up context window space.
# Always blocks — compaction is always worth saving before.

STATE_DIR="$HOME/.mempalace/hook_state"
mkdir -p "$STATE_DIR"

MEMPAL_DIR=""

INPUT=$(cat)

SESSION_ID=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('session_id','unknown'))" 2>/dev/null)

echo "[$(date '+%H:%M:%S')] PRE-COMPACT triggered for session $SESSION_ID" >> "$STATE_DIR/hook.log"

if [ -n "$MEMPAL_DIR" ] && [ -d "$MEMPAL_DIR" ]; then
  python3 -m mempalace mine "$MEMPAL_DIR" >> "$STATE_DIR/hook.log" 2>&1
fi

cat << 'HOOKJSON'
{
  "decision": "block",
  "reason": "COMPACTION IMMINENT. Save ALL topics, decisions, quotes, code, and important context from this session to your memory system. Be thorough — after compaction, detailed context will be lost. Organize into appropriate categories. Use verbatim quotes where possible. Save everything, then allow compaction to proceed."
}
HOOKJSON
