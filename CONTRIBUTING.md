# Contributing to lua-resty-ngxstats

Thank you for your interest in contributing! This document provides guidelines and instructions for contributing to the project.

## Code of Conduct

Be respectful, constructive, and professional in all interactions.

## Getting Started

### Prerequisites

- OpenResty or NGINX with Lua support
- Lua 5.1+ or LuaJIT
- Docker (for testing)
- Git

### Development Setup

1. Fork the repository
2. Clone your fork:
```bash
git clone https://github.com/YOUR_USERNAME/lua-resty-ngxstats.git
cd lua-resty-ngxstats
```

3. Install development dependencies:
```bash
luarocks install luacheck
luarocks install busted
```

4. Build and run:
```bash
make build
make run_dev
```

## Development Workflow

### 1. Create a Feature Branch

```bash
git checkout -b feature/your-feature-name
```

Use prefixes: `feature/`, `fix/`, `docs/`, `test/`, `refactor/`

### 2. Make Changes

Follow the coding standards (see below).

### 3. Run Tests

```bash
# Lint your code
make lint

# Run unit tests
make test

# Build Docker image
make build
```

All checks must pass before submitting a PR.

### 4. Commit Your Changes

Follow conventional commit format:

```
<type>: <description>

[optional body]

[optional footer]
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `test`: Adding or updating tests
- `refactor`: Code refactoring
- `chore`: Maintenance tasks
- `ci`: CI/CD changes

Example:
```bash
git commit -m "feat: add SSL/TLS metrics tracking

Track ssl_protocol and ssl_cipher for HTTPS connections.
Adds new Prometheus metrics for SSL session analysis.

Closes #123"
```

### 5. Push and Create PR

```bash
git push origin feature/your-feature-name
```

Create a pull request on GitHub with:
- Clear description of changes
- Reference to related issues
- Screenshots/examples if applicable

## Coding Standards

### Lua Style

- **Indentation:** 4 spaces (no tabs)
- **Line length:** Max 100 characters
- **Variables:** Use `local` for all variables
- **Naming:**
  - Functions: `snake_case`
  - Variables: `snake_case`
  - Constants: `UPPER_CASE`
  - Modules: `_M` pattern

### Module Pattern

All modules should follow this pattern:

```lua
--[[
  Module description
]]--

local _M = {}

-- Private function
local function helper()
    -- implementation
end

--[[
  Public function documentation
  @param arg1 - Description
  @return result - Description
]]--
function _M.public_function(arg1)
    -- implementation
end

return _M
```

### Error Handling

- Always validate input parameters
- Use `common.errlog()` for error logging
- Return `nil, error_message` on failures
- Check return values from all ngx.shared operations

Example:
```lua
function _M.increment(stats, key, value)
    if not key or key == "" then
        return nil, "key cannot be empty"
    end

    local newval, err = stats:incr(key, value)
    if not newval then
        common.errlog("Failed to increment ", key, ": ", err)
        return nil, err
    end

    return newval
end
```

### Documentation

- Add file-level comments explaining module purpose
- Document all public functions with parameters and return values
- Include usage examples for complex functions
- Update README.md for new features

## Testing

### Writing Tests

Tests use the busted framework. Create test files in `spec/`:

```lua
describe("my_module", function()
    local my_module

    before_each(function()
        package.loaded['stats.my_module'] = nil
        my_module = require "stats.my_module"
    end)

    describe("my_function()", function()
        it("should handle valid input", function()
            local result = my_module.my_function("test")
            assert.equals("expected", result)
        end)

        it("should handle invalid input", function()
            local result, err = my_module.my_function(nil)
            assert.is_nil(result)
            assert.is_not_nil(err)
        end)
    end)
end)
```

### Test Coverage

- Aim for >80% coverage on new code
- Test edge cases and error conditions
- Use mocks from `spec/helpers.lua`

## Adding New Metrics

1. Update `lib/resty/log.lua` to collect the metric
2. Update `lib/resty/prometheus.lua` to format it
3. Add metadata to `metric_info` table in prometheus.lua
4. Write tests in `spec/prometheus_spec.lua`
5. Update README.md metrics table
6. Add example output to README.md

Example:
```lua
-- In log.lua
local ssl_protocol = ngx.var.ssl_protocol
if ssl_protocol then
    common.incr_or_create(stats,
        common.key({'server_zones', group, 'ssl', ssl_protocol}), 1)
end

-- In prometheus.lua metric_info
["server_zone_ssl_total"] = {
    help = "Total requests per SSL/TLS protocol version",
    type = "counter"
}

-- In prometheus.lua parse_metric()
elseif parts[3] == "ssl" then
    metric.name = "nginx_server_zone_ssl_total"
    metric.labels.protocol = parts[4]
    metric.value = value
end
```

## Pull Request Process

1. **Update documentation** - README, CHANGELOG, code comments
2. **Add tests** - For new features or bug fixes
3. **Run all checks** - `make lint && make test && make build`
4. **Update CHANGELOG.md** - Add entry under "Unreleased"
5. **Create PR** with clear description
6. **Respond to feedback** - Address review comments promptly
7. **Squash commits** if requested before merge

### PR Checklist

- [ ] Code follows style guidelines
- [ ] Tests added/updated and passing
- [ ] Documentation updated
- [ ] CHANGELOG.md updated
- [ ] Commit messages follow convention
- [ ] No merge conflicts

## Release Process

(For maintainers)

1. Update version in `dist.ini`
2. Update CHANGELOG.md (move Unreleased to version)
3. Create git tag: `git tag -a v1.0.0 -m "Release 1.0.0"`
4. Push tag: `git push origin v1.0.0`
5. GitHub Actions will build and publish

## Getting Help

- **Issues:** Open an issue for bugs or feature requests
- **Discussions:** Use GitHub Discussions for questions
- **Security:** Email security issues privately (see SECURITY.md)

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
