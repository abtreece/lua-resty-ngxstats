package = "lua-resty-ngxstats"
version = "1.1.0-1"
source = {
    url = "git+https://github.com/abtreece/lua-resty-ngxstats.git",
    tag = "v1.1.0"
}
description = {
    summary = "OpenResty/NGINX metrics collection and Prometheus exporter",
    detailed = [[
        lua-resty-ngxstats is a production-ready NGINX metrics exporter
        for OpenResty. It collects connection, request, server zone,
        upstream, and cache metrics, outputting them in Prometheus
        text exposition format.

        Features:
        - Prometheus text format with HELP/TYPE comments
        - Connection metrics (active, accepted, handled, reading, writing, idle)
        - Request metrics (total, current)
        - Server zone metrics with response status codes
        - HTTP method tracking (GET, POST, etc.)
        - Request timing metrics
        - SSL/TLS protocol tracking
        - Upstream metrics with response times
        - Cache metrics (hit, miss, bypass, etc.)
    ]],
    homepage = "https://github.com/abtreece/lua-resty-ngxstats",
    license = "MIT",
    maintainer = "Britt Treece"
}
dependencies = {
    "lua >= 5.1"
}
build = {
    type = "builtin",
    modules = {
        ["resty.ngxstats"] = "lib/resty/ngxstats/init.lua",
        ["resty.ngxstats.common"] = "lib/resty/ngxstats/common.lua",
        ["resty.ngxstats.log"] = "lib/resty/ngxstats/log.lua",
        ["resty.ngxstats.prometheus"] = "lib/resty/ngxstats/prometheus.lua",
        ["resty.ngxstats.show"] = "lib/resty/ngxstats/show.lua",
        ["resty.ngxstats.status"] = "lib/resty/ngxstats/status.lua",
        ["resty.ngxstats.version"] = "lib/resty/ngxstats/version.lua",
    }
}
