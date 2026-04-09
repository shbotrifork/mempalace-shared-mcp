# Shared MemPalace MCP Server

Run a single [mempalace](https://github.com/milla-jovovich/mempalace) instance as a network MCP service so **every** Claude Code session shares the same AI memory — whether on the host, in WSL, or inside Docker containers.

## Quick start

```bash
# Clone and enter
git clone <this-repo>
cd mempalace-shared-mcp

# Run setup (installs CLI, copies hooks, builds Docker, configures Claude Code)
bash setup.sh

# Mine your first project
mempalace init ~/projects/my-app
mempalace mine ~/projects/my-app

# Restart Claude Code — mempalace tools are now available
```

## Architecture

```
┌──────────────────────────────────────────────────────┐
│  Host machine (Docker Compose)                       │
│                                                      │
│  mempalace MCP server  ←── stdio ──→  supergateway   │
│  (python -m mempalace.mcp_server)     (port 8377)    │
│                                                      │
│  Palace data: ~/.mempalace/ (bind-mounted from host) │
└──────────────────────┬───────────────────────────────┘
                       │ HTTP (streamable-http)
          ┌────────────┼────────────┐
          │            │            │
     Host machine   WSL/Linux    Docker container
     Claude Code    Claude Code  Claude Code
     localhost       localhost    host.docker.internal
```

One process owns the ChromaDB files. All clients connect over HTTP. No lock contention, no sync needed.

## Prerequisites

- Docker and Docker Compose
- Python >= 3.9 with `pip` (for the mempalace CLI — used for mining only)
- Claude Code

## Step-by-step setup

### 1. Install mempalace CLI

```bash
pip install mempalace==3.0.0
```

### 2. Initialize and mine your projects

Mining ingests project files into the palace so they're searchable via semantic search.

```bash
mempalace init ~/projects/my-app
mempalace mine ~/projects/my-app
```

For conversation exports (Claude, ChatGPT, Slack):

```bash
mempalace mine ~/chats/ --mode convos
```

Verify:

```bash
mempalace status
```

> **Tip:** You only need to mine on the host. The Docker container reads the same palace data via bind mount. No restart needed after mining new projects.

### 3. Start the Docker service

Mempalace's MCP server is stdio-only. The Docker container runs [supergateway](https://github.com/supercorp-ai/supergateway) to expose it as a streamable-http endpoint.

```bash
docker compose up -d
```

Verify:

```bash
curl -s http://localhost:8377/mcp -X POST \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '{"jsonrpc":"2.0","method":"initialize","id":1,"params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"0.1"}}}'
```

Expected: `event: message` followed by JSON containing `"serverInfo":{"name":"mempalace","version":"2.0.0"}`.

Manage:

```bash
docker compose logs -f      # watch logs
docker compose restart      # restart
docker compose down         # stop (won't auto-restart until you `up -d` again)
docker compose stop         # pause (will auto-restart when Docker starts)
```

The `restart: unless-stopped` policy means the container automatically starts with Docker. Only `docker compose down` prevents auto-restart.

> **Note:** The `MEMPALACE_PALACE_PATH` env var in `docker-compose.yml` overrides the config file's palace path, which may contain a host-specific path (e.g. Windows `C:\Users\...`). This ensures the container always uses the Linux mount path.
>
> On Windows, if `~` doesn't resolve in the volume mount, replace `~/.mempalace` with `${USERPROFILE}/.mempalace`.

### 4. Connect Claude Code

**Global (all projects — recommended):**

```bash
claude mcp add --transport http --scope user mempalace http://localhost:8377/mcp
```

Or manually add to `~/.claude.json` under the top-level `mcpServers` key:

```json
{
  "mcpServers": {
    "mempalace": {
      "type": "http",
      "url": "http://localhost:8377/mcp"
    }
  }
}
```

### 5. Connect from WSL

WSL2 shares Docker Desktop's network, so `localhost:8377` works directly. Use the same configuration as step 4.

If `localhost` doesn't resolve (older WSL2 setups), find the host IP:

```bash
cat /etc/resolv.conf | grep nameserver | awk '{print $2}'
```

### 6. Connect from Docker containers

Docker containers can't use `localhost` to reach the host machine. Use `host.docker.internal` instead.

**Docker Desktop (Windows/Mac):** `host.docker.internal` resolves automatically.

**Docker on Linux:** Add the mapping explicitly:

```yaml
services:
  my-service:
    extra_hosts:
      - "host.docker.internal:host-gateway"
```

MCP config inside the container:

```json
{
  "mcpServers": {
    "mempalace": {
      "type": "http",
      "url": "http://host.docker.internal:8377/mcp"
    }
  }
}
```

To make this configurable via environment variable, use `.mcp.json`:

```json
{
  "mcpServers": {
    "mempalace": {
      "type": "http",
      "url": "${MEMPALACE_URL:-http://host.docker.internal:8377}/mcp"
    }
  }
}
```

If the container uses `network_mode: host`, it shares the host's network stack and can use `localhost:8377` directly.

## Auto-save hooks (optional)

The `hooks/` directory contains scripts that automatically save session context to the palace:

- **`mempal_save_hook.sh`** — saves every N human messages (default: 15)
- **`mempal_precompact_hook.sh`** — emergency save before context compaction

Install:

```bash
mkdir -p ~/.mempalace/hooks
cp hooks/*.sh ~/.mempalace/hooks/
chmod +x ~/.mempalace/hooks/*.sh
```

Add to Claude Code settings (`~/.claude/settings.json` or `settings.local.json`):

```json
{
  "hooks": {
    "Stop": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "bash \"$HOME/.mempalace/hooks/mempal_save_hook.sh\"",
            "timeout": 30
          }
        ]
      }
    ],
    "PreCompact": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash \"$HOME/.mempalace/hooks/mempal_precompact_hook.sh\"",
            "timeout": 30
          }
        ]
      }
    ]
  }
}
```

> **Note:** The hook scripts use `python3`. On Windows, ensure `python3` resolves correctly (create a shim or alias to your Python install).

## Available MCP tools (19)

| Category | Tools |
|---|---|
| **Palace read** | `mempalace_status`, `mempalace_list_wings`, `mempalace_list_rooms`, `mempalace_get_taxonomy`, `mempalace_search`, `mempalace_check_duplicate` |
| **Palace write** | `mempalace_add_drawer`, `mempalace_delete_drawer` |
| **Knowledge graph** | `mempalace_kg_query`, `mempalace_kg_add`, `mempalace_kg_invalidate`, `mempalace_kg_timeline`, `mempalace_kg_stats` |
| **Navigation** | `mempalace_traverse`, `mempalace_find_tunnels`, `mempalace_graph_stats` |
| **Agent diary** | `mempalace_diary_write`, `mempalace_diary_read` |
| **Reference** | `mempalace_get_aaak_spec` |

## Known issues

| Issue | Details |
|---|---|
| **Very new project** | Released April 2026. Pin your version: `pip install mempalace==3.0.0` |
| **ChromaDB version pinning** | Version conflicts possible if other tools pin chromadb differently. The Docker container isolates this. |
| **Shell injection in hooks** | [Issue #110](https://github.com/milla-jovovich/mempalace/issues/110) — be cautious with auto-save hooks |
| **macOS ARM64 segfault** | [Issue #74](https://github.com/milla-jovovich/mempalace/issues/74) — affects macOS only |
| **Concurrent writes** | Supergateway serializes access (single stdio pipe), so concurrent MCP calls queue. Safe but may add latency under heavy use. |

## Platform notes

| Platform | Notes |
|---|---|
| **Windows (Git Bash)** | Set `MSYS_NO_PATHCONV=1` before commands that use `/mcp` paths. Set `PYTHONIOENCODING=utf-8` for mempalace CLI commands. `python3` may need a shim. |
| **macOS** | Works out of the box. ARM64 users: check issue #74 if using mempalace CLI directly (Docker container is x86 and unaffected). |
| **Linux** | Works out of the box. Use `extra_hosts` for `host.docker.internal` if not on Docker Desktop. |

## Quick reference

| Environment | MCP URL |
|---|---|
| Host machine | `http://localhost:8377/mcp` |
| WSL2 | `http://localhost:8377/mcp` |
| Docker container (Desktop) | `http://host.docker.internal:8377/mcp` |
| Docker container (Linux) | `http://host.docker.internal:8377/mcp` (with `extra_hosts`) |
| Docker container (`network_mode: host`) | `http://localhost:8377/mcp` |
