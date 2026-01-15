# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

lua-resty-ngxstats is an OpenResty/NGINX module that collects request metrics and exposes them in Prometheus text exposition format. It uses NGINX's Lua integration hooks to capture statistics in shared memory and format them for consumption by Prometheus.

## Commands

```bash
make lint      # Run luacheck on ./lib/resty/ngxstats
make test      # Run busted unit tests
make build     # Build Docker image (ngxstats-nginx)
make run_dev   # Run container with volume mounts for hot-reload development
./test.sh      # Load test with hey tool to populate statistics
```

Access points when running:
- Port 80: Main proxy server with test endpoints
- Port 8080: Admin server (`/status` for Prometheus metrics, `/nginx_status` for stub status)

## Git Commit Guidelines

- All commits should be authored by the repository owner
- Do NOT include Co-Authored-By lines or AI attribution in commit messages
- Use conventional commit format: `<type>: <description>`
- Keep commit messages clear and concise

## Architecture

### Directory Structure

```
lib/resty/ngxstats/
├── init.lua        # Startup initialization, version info
├── common.lua      # Core utilities for metrics
├── log.lua         # Request metrics collection
├── status.lua      # NGINX connection metrics capture
├── prometheus.lua  # Prometheus format output
├── show.lua        # Content handler for /status endpoint
└── version.lua     # Single source of truth for version
```

### Data Flow

```
Request → NGINX → [log_by_lua] log.lua → shared memory
                                              ↓
GET /status → [access_by_lua] status.lua → capture nginx_status
            → [content_by_lua] show.lua  → format Prometheus response
```

### Lua Hook Integration

| Hook | File | Purpose |
|------|------|---------|
| `init_by_lua_file` | init.lua | Startup initialization |
| `log_by_lua_file` | log.lua | Collect metrics after each request |
| `access_by_lua_file` | status.lua | Capture NGINX stub_status |
| `content_by_lua_file` | show.lua | Format and return Prometheus response |

### Module Naming Convention

This project follows the lua-resty-* naming convention:
- Modules are in `lib/resty/ngxstats/`
- Import as `require "resty.ngxstats.common"` etc.
- Main module: `require "resty.ngxstats"` returns version info

### Shared Memory Pattern

Statistics are stored in `ngx.shared.ngx_stats` using colon-delimited keys:
- `server_zones:example_com:requests` → counter
- `upstreams:backend:response_time` → accumulator
- `upstreams:backend:server` → string (last upstream address)

The `prometheus.lua` module converts flat keys to Prometheus format with labels.

### Key Modules

- **common.lua**: Core utilities - `incr_or_create()` for counters, `key()` for path building, `safe_tonumber/tostring()` for validation
- **log.lua**: Metric collection - extracts request/upstream data, updates shared stats
- **status.lua**: Captures and parses NGINX stub_status for connection metrics
- **prometheus.lua**: Formats metrics with HELP/TYPE comments and labels
- **show.lua**: Outputs Prometheus format via content handler

### Metrics Collected

- **connections**: active, accepted, handled, reading, writing, idle
- **requests**: current connections, total count
- **server_zones**: per-server request count, bytes sent/received, response codes (by class and individual), HTTP methods, cache status
- **upstreams**: per-upstream request count, timing metrics (response/queue/connect), bytes, response codes, server address

## Testing

```bash
make lint    # Run luacheck
make test    # Run busted unit tests
```

Tests are in `spec/` using the busted framework with mocks in `spec/helpers.lua`.

## Distribution

This project uses a `.rockspec` file for LuaRocks distribution:
- `lua-resty-ngxstats-1.0.0-1.rockspec`
- Install via: `luarocks install lua-resty-ngxstats`
