# Shared MemPalace MCP Server

Run a single [mempalace](https://github.com/milla-jovovich/mempalace) instance as a network MCP service so **every** Claude Code session shares the same AI memory — whether on the host, in WSL, or inside Docker containers.

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

The Docker service runs on the host machine. All environments connect to it over HTTP.

## Setup

### Host machine (required — run this first)

```bash
git clone https://github.com/shbotrifork/mempalace-shared-mcp.git
cd mempalace-shared-mcp
bash setup-host.sh
```

This builds the Docker service, installs the mempalace CLI, copies auto-save hooks, and configures Claude Code. One script, fully set up.

Then mine your projects:

```bash
mempalace init ~/projects/my-app
mempalace mine ~/projects/my-app
```

Restart Claude Code — 19 mempalace tools are now available.

### WSL (optional)

If you run Claude Code inside WSL, run the client setup from within WSL:

```bash
cd /path/to/mempalace-shared-mcp    # or clone it inside WSL
bash client/setup-wsl.sh
```

This installs the mempalace CLI (for mining WSL-local projects), copies hooks, and configures Claude Code inside WSL. It does **not** start Docker — the host handles that.

### Docker containers (optional)

See [client/setup-container.md](client/setup-container.md) for instructions on connecting Claude Code sessions running inside Docker containers.

## Mining projects

Mining ingests project files into the palace so they're searchable via semantic search.

```bash
mempalace init ~/projects/my-app       # detect rooms from folder structure
mempalace mine ~/projects/my-app       # mine project files
mempalace mine ~/chats/ --mode convos  # mine conversation exports (Claude, ChatGPT, Slack)
mempalace status                       # verify what's been filed
```

The Docker service reads palace data via bind mount — no restart needed after mining.

## Managing the Docker service

```bash
docker compose logs -f      # watch logs
docker compose restart      # restart
docker compose down         # stop (won't auto-restart until you `up -d` again)
docker compose stop         # pause (will auto-restart when Docker starts)
```

The `restart: unless-stopped` policy means the container starts automatically with Docker. Only `docker compose down` prevents auto-restart.

## Auto-save hooks

The setup scripts install two Claude Code hooks:

- **Stop hook** — saves session context every 15 human messages
- **PreCompact hook** — emergency save before context compaction

To activate them, add to your Claude Code settings (`~/.claude/settings.json`):

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

| Environment | MCP URL | Setup |
|---|---|---|
| Host machine | `http://localhost:8377/mcp` | `bash setup-host.sh` |
| WSL2 | `http://localhost:8377/mcp` | `bash client/setup-wsl.sh` |
| Docker container (Desktop) | `http://host.docker.internal:8377/mcp` | See `client/setup-container.md` |
| Docker container (Linux) | `http://host.docker.internal:8377/mcp` (with `extra_hosts`) | See `client/setup-container.md` |
