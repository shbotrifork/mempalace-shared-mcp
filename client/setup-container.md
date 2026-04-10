# Connecting from Docker Containers

Docker containers can't use `localhost` to reach the host. Use `host.docker.internal` instead.

## Docker Desktop (Windows/Mac)

`host.docker.internal` resolves automatically. No extra config needed.

## Docker on Linux

Add the mapping explicitly in your `docker-compose.yml`:

```yaml
services:
  my-service:
    extra_hosts:
      - "host.docker.internal:host-gateway"
```

## Claude Code MCP config

Add this to `~/.claude.json` inside the container (or mount it):

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

## Making it optional (recommended)

If mempalace may or may not be running, use an environment variable so Claude Code only connects when the URL is set:

In your project's `.mcp.json`:

```json
{
  "mcpServers": {
    "mempalace": {
      "type": "http",
      "url": "${MEMPALACE_URL}/mcp"
    }
  }
}
```

Then pass the env var only when mempalace is available:

```yaml
services:
  my-service:
    environment:
      - MEMPALACE_URL=http://host.docker.internal:8377
```

If `MEMPALACE_URL` is not set, Claude Code will skip the server.

## Alternative: `network_mode: host`

If the container uses `network_mode: host`, it shares the host's network stack and can use `localhost:8377` directly. Simpler but removes network isolation.
