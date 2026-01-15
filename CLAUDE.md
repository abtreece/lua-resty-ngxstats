# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

lua-resty-ngxstats is an OpenResty/NGINX module that collects request metrics and exposes them as a JSON API. It uses NGINX's Lua integration hooks to capture statistics in shared memory and format them for consumption.

## Commands

```bash
make lint      # Run luacheck on ./lib/resty
make build     # Build Docker image (ngxstats-nginx)
make run_dev   # Run container with volume mounts for hot-reload development
./test.sh      # Load test with hey tool to populate statistics
```

Access points when running:
- Port 80: Main proxy server with test endpoints
- Port 8080: Admin server (`/status` for JSON stats, `/nginx_status` for stub status)

## Git Commit Guidelines

- All commits should be authored by the repository owner
- Do NOT include Co-Authored-By lines or AI attribution in commit messages
- Use conventional commit format: `<type>: <description>`
- Keep commit messages clear and concise

## Architecture

### Data Flow

```
Request → NGINX → [log_by_lua] log.lua → shared memory
                                              ↓
GET /status → [access_by_lua] status.lua → capture nginx_status
            → [content_by_lua] show.lua  → format JSON response
```

### Lua Hook Integration

| Hook | File | Purpose |
|------|------|---------|
| `init_by_lua_file` | init.lua | Startup initialization |
| `log_by_lua_file` | log.lua | Collect metrics after each request |
| `access_by_lua_file` | status.lua | Capture NGINX stub_status |
| `content_by_lua_file` | show.lua | Format and return JSON response |

### Shared Memory Pattern

Statistics are stored in `ngx.shared.ngx_stats` using colon-delimited keys:
- `server_zones:example_com:requests` → counter
- `upstreams:backend:response_time` → accumulator
- `upstreams:backend:server` → string (last upstream address)

The `common.format_response()` function converts flat keys to nested JSON for output.

### Key Modules

- **common.lua**: Core utilities - `incr_or_create()` for counters, `key()` for path building, `format_response()` for JSON nesting
- **log.lua**: Metric collection - extracts request/upstream data, updates shared stats
- **status.lua**: Captures and parses NGINX stub_status for connection metrics
- **show.lua**: Iterates shared dict keys, builds nested JSON response

### Metrics Collected

- **requests**: current connections, total count
- **server_zones**: per-server request count, bytes sent/received, response codes (by class and individual)
- **upstreams**: per-upstream request count, timing metrics (response/queue/connect), bytes, response codes, server address
