#!/bin/bash
# MemPalace Shared MCP — Quick Setup
#
# Prerequisites: Docker, Docker Compose, pip, Claude Code
#
# This script:
# 1. Installs mempalace CLI (for mining)
# 2. Copies hooks to ~/.mempalace/hooks/
# 3. Builds and starts the Docker service
# 4. Adds mempalace MCP to Claude Code (global)
# 5. Verifies everything works

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOKS_DIR="$HOME/.mempalace/hooks"

echo "=== MemPalace Shared MCP Setup ==="
echo ""

# Step 1: Install mempalace CLI
echo "[1/5] Installing mempalace CLI..."
pip install mempalace==3.0.0 2>&1 | tail -1
echo ""

# Step 2: Copy hooks
echo "[2/5] Installing hooks to $HOOKS_DIR..."
mkdir -p "$HOOKS_DIR"
cp "$SCRIPT_DIR/hooks/mempal_save_hook.sh" "$HOOKS_DIR/"
cp "$SCRIPT_DIR/hooks/mempal_precompact_hook.sh" "$HOOKS_DIR/"
chmod +x "$HOOKS_DIR/mempal_save_hook.sh" "$HOOKS_DIR/mempal_precompact_hook.sh"
echo "  Copied mempal_save_hook.sh"
echo "  Copied mempal_precompact_hook.sh"
echo ""

# Step 3: Build and start Docker service
echo "[3/5] Building and starting Docker service..."
docker compose -f "$SCRIPT_DIR/docker-compose.yml" up -d --build 2>&1 | tail -3
echo ""

# Step 4: Add MCP to Claude Code
echo "[4/5] Adding mempalace MCP to Claude Code (global)..."
if command -v claude &> /dev/null; then
  claude mcp add --transport http --scope user mempalace http://localhost:8377/mcp 2>&1 || echo "  (already configured or manual setup needed — see README)"
else
  echo "  Claude Code CLI not found. Add manually to ~/.claude.json:"
  echo '  "mcpServers": { "mempalace": { "type": "http", "url": "http://localhost:8377/mcp" } }'
fi
echo ""

# Step 5: Verify
echo "[5/5] Verifying..."
sleep 3
RESPONSE=$(curl -s http://localhost:8377/mcp -X POST \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '{"jsonrpc":"2.0","method":"initialize","id":1,"params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"0.1"}}}' 2>/dev/null)

if echo "$RESPONSE" | grep -q "mempalace"; then
  echo "  MemPalace MCP server is running at http://localhost:8377/mcp"
  echo ""
  echo "=== Setup complete! ==="
  echo ""
  echo "Next steps:"
  echo "  1. Mine your projects:  mempalace init ~/my-project && mempalace mine ~/my-project"
  echo "  2. Restart Claude Code to pick up the MCP server"
  echo "  3. (Optional) Add hooks to ~/.claude/settings.json — see README"
else
  echo "  WARNING: Could not reach MCP server. Check: docker compose logs"
  exit 1
fi
