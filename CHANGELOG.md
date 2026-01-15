# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Comprehensive unit test suite using busted framework
- GitHub Actions CI/CD pipeline (lint, test, docker build)
- Complete documentation (README, CONTRIBUTING, CHANGELOG)
- Makefile targets: `test`, `help`
- .busted configuration for test runner

### Changed
- **BREAKING:** Replaced JSON output with Prometheus text format on `/status` endpoint
- Converted all Lua scripts to proper testable modules
- Updated nginx.conf to use `text/plain` content-type for `/status`

### Fixed
- Critical bug: Undefined `response.exit()` crash in status.lua
- Bug: `requests.total` metric using wrong variable
- Bug: nginx.conf ACL logic error (allow all; deny all)
- Added comprehensive error handling to shared memory operations

### Removed
- Spreedly-specific configuration from nginx.conf and test.sh
- Dead and commented-out code from all Lua files
- Global variables (converted to local)

## [1.0.0] - TBD

### Added
- Initial release
- Prometheus text exposition format support
- Connection metrics (active, accepted, handled, reading, writing, idle)
- Request metrics (total, current)
- Server zone metrics (requests, bytes, responses by status code)
- Upstream metrics (requests, response time, connect time, queue time, bytes, server info)
- Cache metrics (hit, miss, bypass, expired, stale, updating, revalidated)
- HTTP method tracking (GET, POST, PUT, DELETE, etc.)
- Shared memory-based metric storage
- Docker containerization with OpenResty
- Input validation for all ngx.var values
- Comprehensive function documentation
- luacheck linting support

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

[Unreleased]: https://github.com/abtreece/lua-resty-ngxstats/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/abtreece/lua-resty-ngxstats/releases/tag/v1.0.0
