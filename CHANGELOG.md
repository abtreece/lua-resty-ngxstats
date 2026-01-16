# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Grafana dashboard** - Pre-built dashboard (`examples/grafana-dashboard.json`) with:
  - Overview panels (request rate, error rate, latency, connections, bandwidth, cache hit rate)
  - Request metrics (rate by zone, response status distribution, HTTP methods, bandwidth)
  - Latency metrics (average latency, p50/p90/p99 percentiles, per-zone breakdown)
  - Upstream metrics (request rate, response time percentiles, failures, bandwidth)
  - Connection metrics (states, accepted/handled rate)
  - SSL/TLS metrics (protocol distribution, session reuse rate)
  - Rate limiting status visualization
  - Template variables for job, zone, and upstream filtering

## [1.1.0] - 2026-01-15

### Added
- **Request timing metrics** - `nginx_server_zone_request_time_seconds` tracks total request processing time per zone
- **SSL/TLS protocol metrics** - `nginx_server_zone_ssl_total` tracks requests by SSL/TLS protocol version (TLSv1.2, TLSv1.3, etc.)
- **Docker improvements**
  - `.dockerignore` file to reduce image size
  - OCI image labels (title, description, version, source, license)
  - `HEALTHCHECK` directive for container health monitoring
- **Deployment examples**
  - `examples/docker-compose.yml` - Complete stack with Prometheus and Grafana
  - `examples/prometheus.yml` - Prometheus scrape configuration
  - `examples/nginx.conf.example` - Production-ready NGINX configuration

### Changed
- **BREAKING:** Restructured module namespace from `stats.*` to `resty.ngxstats.*` for lua-resty-* compatibility
- Modules moved from `lib/resty/*.lua` to `lib/resty/ngxstats/`
- Added `version.lua` as single source of truth for version information
- Created proper `.rockspec` file for LuaRocks distribution

### Removed
- Unused `lib/resty/utils.lua` placeholder file
- CI symlink workaround (no longer needed with proper structure)

## [1.0.0] - 2026-01-15

### Added
- Initial production-ready release
- **Prometheus text exposition format support** with HELP and TYPE comments
- Comprehensive unit test suite (50+ tests) using busted framework
- GitHub Actions CI/CD pipeline (lint, test, docker build)
- Complete documentation (README, CONTRIBUTING, CHANGELOG)
- Connection metrics (active, accepted, handled, reading, writing, idle)
- Request metrics (total, current)
- Server zone metrics (requests, bytes, responses by status code)
- **Cache metrics** (hit, miss, bypass, expired, stale, updating, revalidated)
- **HTTP method tracking** (GET, POST, PUT, DELETE, etc.)
- Upstream metrics (requests, response time, connect time, queue time, bytes, server info)
- Shared memory-based metric storage
- Docker containerization with OpenResty
- Input validation for all ngx.var values with safe_tonumber/safe_tostring helpers
- Comprehensive function documentation
- luacheck linting support and .luacheckrc configuration
- Makefile targets: `test`, `help`
- .busted configuration for test runner

### Changed
- **BREAKING:** Replaced JSON output with Prometheus text format on `/status` endpoint
- Converted all Lua scripts to proper testable modules with `_M` pattern
- Updated nginx.conf to use `text/plain` content-type for `/status`

### Fixed
- Critical bug: Undefined `response.exit()` crash in status.lua
- Critical bug: `requests.total` metric using wrong variable (connections_active → 1)
- Bug: nginx.conf ACL logic error (allow all; deny all → allow 127.0.0.1; deny all)
- Added comprehensive error handling to shared memory operations

### Removed
- Spreedly-specific configuration from nginx.conf and test.sh
- Dead and commented-out code from all Lua files
- Global variables (converted all to local)

### Architecture
- Module-based design with proper `_M` pattern
- Prometheus formatter with HELP and TYPE comments
- Safe numeric/string conversion utilities
- Colon-delimited key format for nested metrics
- Error logging with "ngxstats" prefix

### Documentation
- Complete README with installation, configuration, examples
- Metrics reference table
- Development guide
- Performance characteristics
- Comparison with nginx-module-vts and NGINX Plus

[Unreleased]: https://github.com/abtreece/lua-resty-ngxstats/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/abtreece/lua-resty-ngxstats/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/abtreece/lua-resty-ngxstats/releases/tag/v1.0.0
