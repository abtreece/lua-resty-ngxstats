--[[
  Prometheus format output for lua-resty-ngxstats

  Converts NGINX metrics to Prometheus text exposition format
]]--

local _M = {}

-- Metric metadata: HELP text and TYPE
local metric_info = {
    -- Connection metrics (gauges - current state)
    ["connections_active"] = {
        help = "Current active connections",
        type = "gauge"
    },
    ["connections_reading"] = {
        help = "Current connections reading requests",
        type = "gauge"
    },
    ["connections_writing"] = {
        help = "Current connections writing responses",
        type = "gauge"
    },
    ["connections_idle"] = {
        help = "Current idle keepalive connections",
        type = "gauge"
    },
    ["connections_accepted"] = {
        help = "Total accepted connections",
        type = "counter"
    },
    ["connections_handled"] = {
        help = "Total handled connections",
        type = "counter"
    },

    -- Request metrics
    ["requests_current"] = {
        help = "Current number of requests being processed",
        type = "gauge"
    },
    ["requests_total"] = {
        help = "Total number of requests",
        type = "counter"
    },

    -- Server zone metrics
    ["server_zone_requests_total"] = {
        help = "Total requests per server zone",
        type = "counter"
    },
    ["server_zone_bytes_received"] = {
        help = "Total bytes received from clients per server zone",
        type = "counter"
    },
    ["server_zone_bytes_sent"] = {
        help = "Total bytes sent to clients per server zone",
        type = "counter"
    },
    ["server_zone_responses_total"] = {
        help = "Total responses per server zone by status code",
        type = "counter"
    },
    ["server_zone_methods_total"] = {
        help = "Total requests per server zone by HTTP method",
        type = "counter"
    },
    ["server_zone_cache_total"] = {
        help = "Total cache operations per server zone by status",
        type = "counter"
    },
    ["server_zone_request_time_seconds"] = {
        help = "Total request processing time in seconds per server zone",
        type = "counter"
    },
    ["server_zone_ssl_total"] = {
        help = "Total requests per server zone by SSL/TLS protocol version",
        type = "counter"
    },

    -- Upstream metrics
    ["upstream_requests_total"] = {
        help = "Total requests to upstream",
        type = "counter"
    },
    ["upstream_response_time_seconds"] = {
        help = "Total upstream response time in seconds",
        type = "counter"
    },
    ["upstream_queue_time_seconds"] = {
        help = "Total upstream queue time in seconds",
        type = "counter"
    },
    ["upstream_connect_time_seconds"] = {
        help = "Total upstream connect time in seconds",
        type = "counter"
    },
    ["upstream_bytes_sent"] = {
        help = "Total bytes sent to upstream",
        type = "counter"
    },
    ["upstream_bytes_received"] = {
        help = "Total bytes received from upstream",
        type = "counter"
    },
    ["upstream_responses_total"] = {
        help = "Total upstream responses by status code",
        type = "counter"
    },
    ["upstream_server_info"] = {
        help = "Current upstream server address (value is always 1)",
        type = "gauge"
    }
}

--[[
  Convert a key path to Prometheus metric name and labels
  Examples:
    "connections:active" -> {name="connections_active", labels={}}
    "server_zones:default:requests" -> {name="server_zone_requests_total", labels={zone="default"}}
    "upstreams:example_com:response_time" -> {name="upstream_response_time_seconds", labels={upstream="example_com"}}
]]--
local function parse_metric(key, value)
    local parts = {}
    for part in string.gmatch(key, "[^:]+") do
        table.insert(parts, part)
    end

    local metric = {labels = {}}

    -- Connections metrics
    if parts[1] == "connections" then
        metric.name = "nginx_connections_" .. parts[2]
        metric.value = value

    -- Requests metrics
    elseif parts[1] == "requests" then
        metric.name = "nginx_requests_" .. parts[2]
        metric.value = value

    -- Server zones metrics
    elseif parts[1] == "server_zones" then
        local zone = parts[2]
        metric.labels.zone = zone

        if parts[3] == "requests" then
            metric.name = "nginx_server_zone_requests_total"
            metric.value = value
        elseif parts[3] == "received" then
            metric.name = "nginx_server_zone_bytes_received"
            metric.value = value
        elseif parts[3] == "sent" then
            metric.name = "nginx_server_zone_bytes_sent"
            metric.value = value
        elseif parts[3] == "responses" then
            if parts[4] == "total" then
                metric.name = "nginx_server_zone_responses_total"
                metric.value = value
            else
                -- Individual status code or status class (2xx, 4xx, etc.)
                metric.name = "nginx_server_zone_responses_total"
                metric.labels.status = parts[4]
                metric.value = value
            end
        elseif parts[3] == "methods" then
            -- HTTP method tracking (GET, POST, etc.)
            metric.name = "nginx_server_zone_methods_total"
            metric.labels.method = parts[4]
            metric.value = value
        elseif parts[3] == "cache" then
            -- Cache status tracking (hit, miss, expired, etc.)
            metric.name = "nginx_server_zone_cache_total"
            metric.labels.cache_status = parts[4]
            metric.value = value
        elseif parts[3] == "request_time" then
            -- Total request processing time
            metric.name = "nginx_server_zone_request_time_seconds"
            metric.value = value
        elseif parts[3] == "ssl" then
            -- SSL/TLS protocol tracking (TLSv1.2, TLSv1.3, etc.)
            metric.name = "nginx_server_zone_ssl_total"
            metric.labels.protocol = parts[4]
            metric.value = value
        end

    -- Upstream metrics
    elseif parts[1] == "upstreams" then
        local upstream = parts[2]
        metric.labels.upstream = upstream

        if parts[3] == "requests" then
            metric.name = "nginx_upstream_requests_total"
            metric.value = value
        elseif parts[3] == "response_time" then
            metric.name = "nginx_upstream_response_time_seconds"
            metric.value = value
        elseif parts[3] == "queue_time" then
            metric.name = "nginx_upstream_queue_time_seconds"
            metric.value = value
        elseif parts[3] == "connect_time" then
            metric.name = "nginx_upstream_connect_time_seconds"
            metric.value = value
        elseif parts[3] == "sent" then
            metric.name = "nginx_upstream_bytes_sent"
            metric.value = value
        elseif parts[3] == "received" then
            metric.name = "nginx_upstream_bytes_received"
            metric.value = value
        elseif parts[3] == "server" then
            metric.name = "nginx_upstream_server_info"
            metric.labels.server = tostring(value)
            metric.value = 1  -- Info metric always has value 1
        elseif parts[3] == "responses" then
            if parts[4] == "total" then
                metric.name = "nginx_upstream_responses_total"
                metric.value = value
            else
                metric.name = "nginx_upstream_responses_total"
                metric.labels.status = parts[4]
                metric.value = value
            end
        end
    end

    return metric
end

--[[
  Format labels for Prometheus output
  @param labels - Table of label key-value pairs
  @return string - Formatted label string like {zone="default",status="200"}
]]--
local function format_labels(labels)
    if not next(labels) then
        return ""
    end

    local parts = {}
    for k, v in pairs(labels) do
        table.insert(parts, k .. '="' .. v .. '"')
    end

    return "{" .. table.concat(parts, ",") .. "}"
end

--[[
  Generate Prometheus text format output from metrics
  @param stats - Shared memory dictionary containing metrics
  @return string - Prometheus formatted text
]]--
function _M.format(stats)
    local keys = stats:get_keys()

    -- Group metrics by name to output HELP/TYPE only once per metric
    local metrics_by_name = {}

    for _, key in ipairs(keys) do
        local value = stats:get(key)
        local metric = parse_metric(key, value)

        if metric.name then
            if not metrics_by_name[metric.name] then
                metrics_by_name[metric.name] = {}
            end
            table.insert(metrics_by_name[metric.name], {
                labels = metric.labels,
                value = metric.value
            })
        end
    end

    -- Generate output with HELP and TYPE comments
    local output = {}

    -- Sort metric names for consistent output
    local sorted_names = {}
    for name in pairs(metrics_by_name) do
        table.insert(sorted_names, name)
    end
    table.sort(sorted_names)

    for _, name in ipairs(sorted_names) do
        local metrics = metrics_by_name[name]

        -- Extract base name for metadata lookup (remove nginx_ prefix)
        local base_name = name:gsub("^nginx_", "")
        local info = metric_info[base_name]

        if info then
            -- Add HELP comment
            table.insert(output, "# HELP " .. name .. " " .. info.help)
            -- Add TYPE comment
            table.insert(output, "# TYPE " .. name .. " " .. info.type)
        end

        -- Add metric lines
        for _, m in ipairs(metrics) do
            local line = name .. format_labels(m.labels) .. " " .. tostring(m.value)
            table.insert(output, line)
        end

        -- Add blank line between metric families
        table.insert(output, "")
    end

    return table.concat(output, "\n")
end

return _M
