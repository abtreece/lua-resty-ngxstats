# lua-resty-ngxstats

[![CI](https://github.com/abtreece/lua-resty-ngxstats/actions/workflows/ci.yml/badge.svg)](https://github.com/abtreece/lua-resty-ngxstats/actions/workflows/ci.yml)

> OpenResty/NGINX metrics collection and Prometheus exporter

A lightweight Lua library for OpenResty that collects detailed NGINX metrics and exposes them in Prometheus text format. Track requests, responses, upstream performance, cache efficiency, and more.

## Features

- **Prometheus Format** - Native Prometheus text exposition format with HELP and TYPE comments
- **Connection Metrics** - Active, accepted, handled connections with state tracking
- **Server Zone Metrics** - Per-server request counts, bytes, response codes, HTTP methods
- **Latency Histograms** - Request time histograms with configurable buckets for percentile calculations
- **Upstream Metrics** - Request counts, response times, queue times, connect times, header times, bytes transferred
- **Upstream Failures** - Track failed upstream requests separately
- **Per-Server Metrics** - Individual upstream server request counts and response times
- **Cache Metrics** - Hit, miss, bypass, expired, stale cache operations
- **SSL/TLS Metrics** - Protocol version, cipher suite, and session reuse tracking
- **Rate Limiting** - Track rate limit passes, delays, and rejections
- **HTTP Method Tracking** - GET, POST, PUT, DELETE request distribution
- **Slow Request Tracking** - Count requests exceeding configurable time threshold
- **Request Size Histogram** - Distribution of request body sizes
- **Upstream Health Gauge** - Calculated health status based on failure rate
- **Zero Dependencies** - Pure Lua implementation using OpenResty's built-in APIs

## Installation

### Using Docker (Recommended)

```bash
git clone https://github.com/abtreece/lua-resty-ngxstats.git
cd lua-resty-ngxstats
make build
make run_dev
```

The metrics endpoint will be available at `http://localhost:8080/status`

### Manual Installation

1. Copy the `lib/resty` directory to your OpenResty Lua path:
```bash
cp -r lib/resty /path/to/openresty/lualib/stats
```

2. Configure NGINX (see Configuration section below)

## Quick Start

### 1. Configure nginx.conf

```nginx
http {
    # Shared memory for metrics storage (10MB)
    lua_shared_dict ngx_stats 10m;
    lua_package_path '/etc/nginx/lua/?.lua;/etc/nginx/lua/?/init.lua;;';

    # Initialize on startup
    init_by_lua_file /etc/nginx/lua/resty/ngxstats/init.lua;

    server {
        listen 80;

        # Collect metrics for all requests
        log_by_lua_file /etc/nginx/lua/resty/ngxstats/log.lua;

        location / {
            proxy_pass http://backend;
        }
    }

    # Metrics endpoint
    server {
        listen 8080;

        location /status {
            access_by_lua_file /etc/nginx/lua/resty/ngxstats/status.lua;
            content_by_lua_file /etc/nginx/lua/resty/ngxstats/show.lua;
        }
    }
}
```

### 2. Access Metrics

```bash
curl http://localhost:8080/status
```

### 3. Scrape with Prometheus

```yaml
scrape_configs:
  - job_name: 'nginx'
    static_configs:
      - targets: ['localhost:8080']
    metrics_path: '/status'
```

### 4. Import Grafana Dashboard

Import the pre-built dashboard from `examples/grafana-dashboard.json` or use dashboard ID from Grafana.com (if published).

The dashboard includes:
- **Overview row** - Request rate, error rate, latency, active connections, bandwidth, cache hit rate
- **Request metrics** - Request rate by zone, response status distribution, HTTP methods, bandwidth
- **Latency metrics** - Average latency, percentiles (p50/p90/p99), per-zone breakdown
- **Upstream metrics** - Request rate, response time, percentiles, failures, bandwidth
- **Connection metrics** - Connection states, accepted/handled rate
- **SSL/TLS & Rate limiting** - Protocol distribution, session reuse, rate limit status

### 5. Configure Alerting (Optional)

Use the pre-built alerting rules from `examples/prometheus-alerts.yml`:

```yaml
rule_files:
  - "prometheus-alerts.yml"
```

Included alert groups:
- **Availability** - NGINX down, no requests received
- **Errors** - High 5xx/4xx error rates
- **Latency** - High p99 latency, elevated average latency
- **Upstream** - Failures, high error rate, high latency
- **Connections** - High active connections, unhandled connections
- **Cache** - Low hit rate, high bypass rate
- **Rate Limiting** - High rejection rate
- **SSL/TLS** - Low session reuse, deprecated protocol usage
- **Traffic** - Spikes, drops, high bandwidth

### 6. Datadog Integration (Alternative to Prometheus)

If you use Datadog instead of Prometheus, you can scrape the same metrics using Datadog's OpenMetrics integration.

#### Configure Datadog Agent

Copy `examples/datadog-openmetrics.yaml` to your Datadog Agent configuration directory:

```bash
# Linux
sudo cp examples/datadog-openmetrics.yaml /etc/datadog-agent/conf.d/openmetrics.d/conf.yaml

# Update the endpoint URL if needed
sudo vim /etc/datadog-agent/conf.d/openmetrics.d/conf.yaml

# Restart the agent
sudo systemctl restart datadog-agent
```

#### Import Datadog Dashboard

Import the pre-built dashboard using the Datadog API:

```bash
# Set your API and Application keys
export DD_API_KEY="your-api-key"
export DD_APP_KEY="your-app-key"

# Import the dashboard
curl -X POST "https://api.datadoghq.com/api/v1/dashboard" \
  -H "Content-Type: application/json" \
  -H "DD-API-KEY: ${DD_API_KEY}" \
  -H "DD-APPLICATION-KEY: ${DD_APP_KEY}" \
  -d @examples/datadog-dashboard.json
```

Or import manually via the Datadog UI:
1. Navigate to Dashboards > New Dashboard
2. Click the gear icon > Import dashboard JSON
3. Paste the contents of `examples/datadog-dashboard.json`

The Datadog dashboard includes:
- **Overview** - Request rate, error rate, latency, connections, bandwidth, cache hit rate
- **Request Metrics** - Request rate by zone, response status, HTTP methods, bandwidth
- **Latency Metrics** - Average latency by zone, slow requests
- **Upstream Metrics** - Request rate, response time, failures, bandwidth, health status
- **Connections** - Connection states, accepted/handled rate
- **SSL/TLS & Rate Limiting** - Protocol distribution, session reuse, rate limit status

## Metrics Exposed

### Connection Metrics

| Metric | Type | Description |
|--------|------|-------------|
| `nginx_connections_active` | gauge | Current active connections |
| `nginx_connections_accepted` | counter | Total accepted connections |
| `nginx_connections_handled` | counter | Total handled connections |
| `nginx_connections_reading` | gauge | Connections reading requests |
| `nginx_connections_writing` | gauge | Connections writing responses |
| `nginx_connections_idle` | gauge | Idle keepalive connections |

### Request Metrics

| Metric | Type | Labels | Description |
|--------|------|--------|-------------|
| `nginx_requests_total` | counter | - | Total requests processed |
| `nginx_requests_current` | gauge | - | Current requests being processed |

### Server Zone Metrics

| Metric | Type | Labels | Description |
|--------|------|--------|-------------|
| `nginx_server_zone_requests_total` | counter | `zone` | Total requests per server zone |
| `nginx_server_zone_bytes_received` | counter | `zone` | Bytes received from clients |
| `nginx_server_zone_bytes_sent` | counter | `zone` | Bytes sent to clients |
| `nginx_server_zone_responses_total` | counter | `zone`, `status` | Responses by status code/class |
| `nginx_server_zone_methods_total` | counter | `zone`, `method` | Requests by HTTP method |
| `nginx_server_zone_cache_total` | counter | `zone`, `cache_status` | Cache operations by status |
| `nginx_server_zone_request_time_seconds_sum` | counter | `zone` | Total request processing time |
| `nginx_server_zone_request_time_seconds_count` | counter | `zone` | Number of timed requests |
| `nginx_server_zone_request_time_seconds_bucket` | counter | `zone`, `le` | Request time histogram buckets |
| `nginx_server_zone_ssl_protocol_total` | counter | `zone`, `protocol` | Requests by SSL/TLS protocol |
| `nginx_server_zone_ssl_cipher_total` | counter | `zone`, `cipher` | Requests by SSL/TLS cipher |
| `nginx_server_zone_ssl_sessions_total` | counter | `zone`, `reused` | SSL sessions by reuse status |
| `nginx_server_zone_limit_req_total` | counter | `zone`, `status` | Rate-limited requests by status |
| `nginx_server_zone_slow_requests_total` | counter | `zone` | Requests exceeding 1s threshold |
| `nginx_server_zone_request_length_bytes_bucket` | counter | `zone`, `le` | Request size histogram buckets |

### Upstream Metrics

| Metric | Type | Labels | Description |
|--------|------|--------|-------------|
| `nginx_upstream_requests_total` | counter | `upstream` | Total upstream requests |
| `nginx_upstream_failures_total` | counter | `upstream` | Failed upstream requests |
| `nginx_upstream_response_time_seconds_sum` | counter | `upstream` | Total response time |
| `nginx_upstream_response_time_seconds_count` | counter | `upstream` | Number of timed responses |
| `nginx_upstream_response_time_seconds_bucket` | counter | `upstream`, `le` | Response time histogram buckets |
| `nginx_upstream_header_time_seconds_sum` | counter | `upstream` | Total time to first byte |
| `nginx_upstream_header_time_seconds_count` | counter | `upstream` | Number of header time samples |
| `nginx_upstream_connect_time_seconds` | counter | `upstream` | Total connect time |
| `nginx_upstream_queue_time_seconds` | counter | `upstream` | Total queue time |
| `nginx_upstream_bytes_sent` | counter | `upstream` | Bytes sent to upstream |
| `nginx_upstream_bytes_received` | counter | `upstream` | Bytes received from upstream |
| `nginx_upstream_responses_total` | counter | `upstream`, `status` | Responses by status code |
| `nginx_upstream_server_info` | gauge | `upstream`, `server` | Current upstream server address |
| `nginx_upstream_server_requests_total` | counter | `upstream`, `server` | Requests per upstream server |
| `nginx_upstream_server_response_time_seconds` | counter | `upstream`, `server` | Response time per server |
| `nginx_upstream_health` | gauge | `upstream` | Health status (1=healthy, 0=unhealthy) |

## Example Output

```prometheus
# HELP nginx_connections_active Current active connections
# TYPE nginx_connections_active gauge
nginx_connections_active 5

# HELP nginx_server_zone_requests_total Total requests per server zone
# TYPE nginx_server_zone_requests_total counter
nginx_server_zone_requests_total{zone="default"} 1000

# HELP nginx_server_zone_methods_total Total requests per server zone by HTTP method
# TYPE nginx_server_zone_methods_total counter
nginx_server_zone_methods_total{zone="default",method="GET"} 800
nginx_server_zone_methods_total{zone="default",method="POST"} 200

# HELP nginx_upstream_response_time_seconds Total upstream response time in seconds
# TYPE nginx_upstream_response_time_seconds counter
nginx_upstream_response_time_seconds{upstream="example_com"} 12.5
```

## Development

### Prerequisites

- OpenResty or NGINX with Lua support
- Lua 5.1+ or LuaJIT
- luacheck (for linting)
- busted (for testing)

### Running Tests

```bash
# Install dependencies
luarocks install luacheck
luarocks install busted

# Run linter
make lint

# Run unit tests
make test
```

### Building and Testing Locally

```bash
# Build Docker image
make build

# Run in development mode (with volume mounts)
make run_dev

# Generate test traffic
./test.sh
```

## Configuration

### Shared Memory Size

Adjust the shared dictionary size based on your traffic:

```nginx
lua_shared_dict ngx_stats 10m;  # 10MB for ~50,000 metrics
lua_shared_dict ngx_stats 100m; # 100MB for high-cardinality scenarios
```

### Server Zone Grouping

Metrics are grouped by `server_name`. Use different server names for logical separation:

```nginx
server {
    server_name api.example.com;  # Metrics under zone="api_example_com"
    # ...
}

server {
    server_name www.example.com;  # Metrics under zone="www_example_com"
    # ...
}
```

### Cache Metrics

Enable cache metrics by configuring `proxy_cache`:

```nginx
proxy_cache_path /tmp levels=1:2 keys_zone=cache:10m;

location / {
    proxy_cache cache;
    proxy_pass http://backend;
}
```

## Performance

- **Overhead:** < 1% CPU overhead per request
- **Memory:** ~200 bytes per unique metric
- **Latency:** < 1ms added to request processing

## Comparison

| Feature | lua-resty-ngxstats | nginx-module-vts | NGINX Plus |
|---------|-------------------|------------------|------------|
| License | MIT | BSD | Commercial |
| Installation | Lua module | C module compile | Binary |
| Prometheus format | ✅ | ✅ | ✅ |
| Cache metrics | ✅ | ✅ | ✅ |
| HTTP methods | ✅ | ✅ | ✅ |
| Upstream health | ✅ | Partial | ✅ |
| Percentiles | ✅ (histograms) | ❌ | ✅ |

## License

MIT License - see [LICENSE](LICENSE) file for details

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development guidelines.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for release history.

## Author

Britt Treece ([@abtreece](https://github.com/abtreece))
