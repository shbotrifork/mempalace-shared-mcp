#!/bin/bash
# MemPalace WSL Client Setup
#
# Run this inside WSL to connect to the mempalace MCP server
# running on the Windows host.
#
# Prerequisites:
#   - mempalace Docker service running on the host (run setup-host.sh first)
#   - Python 3.9+ with pip
#   - Claude Code installed in WSL
#
# This script does NOT start Docker — the host handles that.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
HOOKS_DIR="$HOME/.mempalace/hooks"
MCP_URL="http://localhost:8377/mcp"

echo "=== MemPalace WSL Client Setup ==="
echo ""

# Step 1: Verify the host service is reachable
echo "[1/4] Checking host MCP service..."
RESPONSE=$(curl -s "$MCP_URL" -X POST \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '{"jsonrpc":"2.0","method":"initialize","id":1,"params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"0.1"}}}' 2>/dev/null)

if echo "$RESPONSE" | grep -q "mempalace"; then
  echo "  Host service reachable at $MCP_URL"
else
  echo "  ERROR: Cannot reach mempalace at $MCP_URL"
  echo "  Make sure the Docker service is running on the host (run setup-host.sh first)"
  exit 1
fi
echo ""

# Step 2: Install mempalace CLI (for mining WSL-local projects)
echo "[2/4] Installing mempalace CLI..."
pip install mempalace==3.0.0 2>&1 | tail -1
echo ""

# Step 3: Copy hooks
echo "[3/4] Installing hooks to $HOOKS_DIR..."
mkdir -p "$HOOKS_DIR"
cp "$REPO_DIR/hooks/mempal_save_hook.sh" "$HOOKS_DIR/"
cp "$REPO_DIR/hooks/mempal_precompact_hook.sh" "$HOOKS_DIR/"
chmod +x "$HOOKS_DIR/mempal_save_hook.sh" "$HOOKS_DIR/mempal_precompact_hook.sh"
echo "  Copied mempal_save_hook.sh"
echo "  Copied mempal_precompact_hook.sh"
echo ""

# Step 4: Add MCP to Claude Code
echo "[4/4] Adding mempalace MCP to Claude Code (global)..."
if command -v claude &> /dev/null; then
  claude mcp add --transport http --scope user mempalace "$MCP_URL" 2>&1 || echo "  (already configured or manual setup needed — see README)"
else
  echo "  Claude Code CLI not found. Add manually to ~/.claude.json:"
  echo "  \"mcpServers\": { \"mempalace\": { \"type\": \"http\", \"url\": \"$MCP_URL\" } }"
fi
echo ""

echo "=== WSL client setup complete! ==="
echo ""
echo "Next steps:"
echo "  1. Mine your WSL projects:  mempalace init ~/my-project && mempalace mine ~/my-project"
echo "  2. Restart Claude Code in WSL to pick up the MCP server"
echo "  3. (Optional) Add hooks to ~/.claude/settings.json — see README"
echo ""
echo "Note: Mining in WSL writes to ~/.mempalace/ inside WSL, which is separate"
echo "from the Windows host palace. If you want a single shared palace, mine from"
echo "the host using the Windows path to your WSL files (/mnt/c/... or \\\\wsl$\\...)."
