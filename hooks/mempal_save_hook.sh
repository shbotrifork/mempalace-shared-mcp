#!/bin/bash
# MEMPALACE SAVE HOOK — Auto-save every N exchanges
#
# Claude Code "Stop" hook. After every assistant response:
# 1. Counts human messages in the session transcript
# 2. Every SAVE_INTERVAL messages, BLOCKS the AI from stopping
# 3. Returns a reason telling the AI to save structured diary + palace entries
# 4. AI does the save (topics, decisions, code, quotes → organized into palace)
# 5. Next Stop fires with stop_hook_active=true → lets AI stop normally

SAVE_INTERVAL=15
STATE_DIR="$HOME/.mempalace/hook_state"
mkdir -p "$STATE_DIR"

MEMPAL_DIR=""

INPUT=$(cat)

SESSION_ID=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('session_id','unknown'))" 2>/dev/null)
SESSION_ID=$(echo "$SESSION_ID" | tr -cd 'a-zA-Z0-9_-')
[ -z "$SESSION_ID" ] && SESSION_ID="unknown"
STOP_HOOK_ACTIVE=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('stop_hook_active', False))" 2>/dev/null)
TRANSCRIPT_PATH=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('transcript_path',''))" 2>/dev/null)

TRANSCRIPT_PATH="${TRANSCRIPT_PATH/#\~/$HOME}"

if [ "$STOP_HOOK_ACTIVE" = "True" ] || [ "$STOP_HOOK_ACTIVE" = "true" ]; then
  echo "{}"
  exit 0
fi

if [ -f "$TRANSCRIPT_PATH" ]; then
  EXCHANGE_COUNT=$(python3 - "$TRANSCRIPT_PATH" <<'PYEOF'
import json, sys
count = 0
with open(sys.argv[1]) as f:
  for line in f:
    try:
      entry = json.loads(line)
      msg = entry.get('message', {})
      if isinstance(msg, dict) and msg.get('role') == 'user':
        content = msg.get('content', '')
        if isinstance(content, str) and '<command-message>' in content:
          continue
        count += 1
    except:
      pass
print(count)
PYEOF
2>/dev/null)
else
  EXCHANGE_COUNT=0
fi

LAST_SAVE_FILE="$STATE_DIR/${SESSION_ID}_last_save"
LAST_SAVE=0
if [ -f "$LAST_SAVE_FILE" ]; then
  LAST_SAVE=$(cat "$LAST_SAVE_FILE")
fi

SINCE_LAST=$((EXCHANGE_COUNT - LAST_SAVE))

echo "[$(date '+%H:%M:%S')] Session $SESSION_ID: $EXCHANGE_COUNT exchanges, $SINCE_LAST since last save" >> "$STATE_DIR/hook.log"

if [ "$SINCE_LAST" -ge "$SAVE_INTERVAL" ] && [ "$EXCHANGE_COUNT" -gt 0 ]; then
  echo "$EXCHANGE_COUNT" > "$LAST_SAVE_FILE"
  echo "[$(date '+%H:%M:%S')] TRIGGERING SAVE at exchange $EXCHANGE_COUNT" >> "$STATE_DIR/hook.log"

  if [ -n "$MEMPAL_DIR" ] && [ -d "$MEMPAL_DIR" ]; then
    python3 -m mempalace mine "$MEMPAL_DIR" >> "$STATE_DIR/hook.log" 2>&1 &
  fi

  cat << 'HOOKJSON'
{
  "decision": "block",
  "reason": "AUTO-SAVE checkpoint. Save key topics, decisions, quotes, and code from this session to your memory system. Organize into appropriate categories. Use verbatim quotes where possible. Continue conversation after saving."
}
HOOKJSON
else
  echo "{}"
fi
