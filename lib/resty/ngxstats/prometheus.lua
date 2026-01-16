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
    ["server_zone_request_time_seconds_sum"] = {
        help = "Total request processing time in seconds per server zone",
        type = "counter"
    },
    ["server_zone_request_time_seconds_count"] = {
        help = "Total number of requests with timing per server zone",
        type = "counter"
    },
    ["server_zone_request_time_seconds_bucket"] = {
        help = "Request time histogram bucket per server zone",
        type = "counter"
    },
    ["server_zone_ssl_protocol_total"] = {
        help = "Total requests per server zone by SSL/TLS protocol version",
        type = "counter"
    },
    ["server_zone_ssl_cipher_total"] = {
        help = "Total requests per server zone by SSL/TLS cipher suite",
        type = "counter"
    },
    ["server_zone_ssl_sessions_total"] = {
        help = "Total SSL sessions per server zone by reuse status",
        type = "counter"
    },
    ["server_zone_limit_req_total"] = {
        help = "Total rate-limited requests per server zone by status",
        type = "counter"
    },

    -- Upstream metrics
    ["upstream_requests_total"] = {
        help = "Total requests to upstream",
        type = "counter"
    },
    ["upstream_failures_total"] = {
        help = "Total failed upstream requests",
        type = "counter"
    },
    ["upstream_response_time_seconds_sum"] = {
        help = "Total upstream response time in seconds",
        type = "counter"
    },
    ["upstream_response_time_seconds_count"] = {
        help = "Total number of upstream responses with timing",
        type = "counter"
    },
    ["upstream_response_time_seconds_bucket"] = {
        help = "Upstream response time histogram bucket",
        type = "counter"
    },
    ["upstream_header_time_seconds_sum"] = {
        help = "Total upstream time to first byte in seconds",
        type = "counter"
    },
    ["upstream_header_time_seconds_count"] = {
        help = "Total number of upstream responses with header timing",
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
    },
    ["upstream_server_requests_total"] = {
        help = "Total requests per upstream server",
        type = "counter"
    },
    ["upstream_server_response_time_seconds"] = {
        help = "Total response time per upstream server in seconds",
        type = "counter"
    }
}

--[[
  Split a colon-delimited key into parts
  @param key - The key string to split
  @return table - Array of key parts
]]--
local function split_key(key)
    local parts = {}
    for part in string.gmatch(key, "[^:]+") do
        table.insert(parts, part)
    end
    return parts
end

--[[
  Server zone metric handlers
  Each handler takes (parts, value, metric) and populates the metric table
]]--
local server_zone_handlers = {
    requests = function(parts, value, metric)
        metric.name = "nginx_server_zone_requests_total"
        metric.value = value
    end,
    received = function(parts, value, metric)
        metric.name = "nginx_server_zone_bytes_received"
        metric.value = value
    end,
    sent = function(parts, value, metric)
        metric.name = "nginx_server_zone_bytes_sent"
        metric.value = value
    end,
    responses = function(parts, value, metric)
        metric.name = "nginx_server_zone_responses_total"
        metric.value = value
        if parts[4] and parts[4] ~= "total" then
            metric.labels.status = parts[4]
        end
    end,
    methods = function(parts, value, metric)
        metric.name = "nginx_server_zone_methods_total"
        metric.labels.method = parts[4]
        metric.value = value
    end,
    cache = function(parts, value, metric)
        metric.name = "nginx_server_zone_cache_total"
        metric.labels.cache_status = parts[4]
        metric.value = value
    end,
    request_time_sum = function(parts, value, metric)
        metric.name = "nginx_server_zone_request_time_seconds_sum"
        metric.value = value
    end,
    request_time_count = function(parts, value, metric)
        metric.name = "nginx_server_zone_request_time_seconds_count"
        metric.value = value
    end,
    request_time_bucket = function(parts, value, metric)
        metric.name = "nginx_server_zone_request_time_seconds_bucket"
        metric.labels.le = parts[4]
        metric.value = value
    end,
    limit_req = function(parts, value, metric)
        metric.name = "nginx_server_zone_limit_req_total"
        metric.labels.status = parts[4]
        metric.value = value
    end
}

--[[
  SSL metric handlers for server zones
]]--
local ssl_handlers = {
    protocol = function(parts, value, metric)
        metric.name = "nginx_server_zone_ssl_protocol_total"
        metric.labels.protocol = parts[5]
        metric.value = value
    end,
    cipher = function(parts, value, metric)
        metric.name = "nginx_server_zone_ssl_cipher_total"
        metric.labels.cipher = parts[5]
        metric.value = value
    end,
    session_reused = function(parts, value, metric)
        metric.name = "nginx_server_zone_ssl_sessions_total"
        metric.labels.reused = "true"
        metric.value = value
    end,
    session_new = function(parts, value, metric)
        metric.name = "nginx_server_zone_ssl_sessions_total"
        metric.labels.reused = "false"
        metric.value = value
    end
}

--[[
  Upstream metric handlers
]]--
local upstream_handlers = {
    requests = function(parts, value, metric)
        metric.name = "nginx_upstream_requests_total"
        metric.value = value
    end,
    failures = function(parts, value, metric)
        metric.name = "nginx_upstream_failures_total"
        metric.value = value
    end,
    response_time_sum = function(parts, value, metric)
        metric.name = "nginx_upstream_response_time_seconds_sum"
        metric.value = value
    end,
    response_time_count = function(parts, value, metric)
        metric.name = "nginx_upstream_response_time_seconds_count"
        metric.value = value
    end,
    response_time_bucket = function(parts, value, metric)
        metric.name = "nginx_upstream_response_time_seconds_bucket"
        metric.labels.le = parts[4]
        metric.value = value
    end,
    header_time_sum = function(parts, value, metric)
        metric.name = "nginx_upstream_header_time_seconds_sum"
        metric.value = value
    end,
    header_time_count = function(parts, value, metric)
        metric.name = "nginx_upstream_header_time_seconds_count"
        metric.value = value
    end,
    queue_time = function(parts, value, metric)
        metric.name = "nginx_upstream_queue_time_seconds"
        metric.value = value
    end,
    connect_time = function(parts, value, metric)
        metric.name = "nginx_upstream_connect_time_seconds"
        metric.value = value
    end,
    sent = function(parts, value, metric)
        metric.name = "nginx_upstream_bytes_sent"
        metric.value = value
    end,
    received = function(parts, value, metric)
        metric.name = "nginx_upstream_bytes_received"
        metric.value = value
    end,
    server = function(parts, value, metric)
        metric.name = "nginx_upstream_server_info"
        metric.labels.server = tostring(value)
        metric.value = 1  -- Info metric always has value 1
    end,
    responses = function(parts, value, metric)
        metric.name = "nginx_upstream_responses_total"
        metric.value = value
        if parts[4] and parts[4] ~= "total" then
            metric.labels.status = parts[4]
        end
    end
}

--[[
  Upstream server metric handlers (per-server metrics)
]]--
local upstream_server_handlers = {
    requests = function(parts, value, metric)
        metric.name = "nginx_upstream_server_requests_total"
        metric.value = value
    end,
    response_time = function(parts, value, metric)
        metric.name = "nginx_upstream_server_response_time_seconds"
        metric.value = value
    end
}

--[[
  Parse server zone metrics
  @param parts - Key parts array
  @param value - Metric value
  @param metric - Metric table to populate
]]--
local function parse_server_zone(parts, value, metric)
    metric.labels.zone = parts[2]

    -- Handle SSL metrics separately (they have a sub-category)
    if parts[3] == "ssl" then
        local handler = ssl_handlers[parts[4]]
        if handler then
            handler(parts, value, metric)
        end
        return
    end

    -- Handle other server zone metrics
    local handler = server_zone_handlers[parts[3]]
    if handler then
        handler(parts, value, metric)
    end
end

--[[
  Parse upstream metrics
  @param parts - Key parts array
  @param value - Metric value
  @param metric - Metric table to populate
]]--
local function parse_upstream(parts, value, metric)
    metric.labels.upstream = parts[2]

    -- Handle per-server metrics
    if parts[3] == "servers" then
        local server_addr = parts[4]
        metric.labels.server = string.gsub(server_addr, "_", ".")
        local handler = upstream_server_handlers[parts[5]]
        if handler then
            handler(parts, value, metric)
        end
        return
    end

    -- Handle other upstream metrics
    local handler = upstream_handlers[parts[3]]
    if handler then
        handler(parts, value, metric)
    end
end

--[[
  Convert a key path to Prometheus metric name and labels
  Examples:
    "connections:active" -> {name="connections_active", labels={}}
    "server_zones:default:requests" -> {name="server_zone_requests_total", labels={zone="default"}}
    "upstreams:example_com:response_time" -> {name="upstream_response_time_seconds", labels={upstream="example_com"}}

  @param key - Colon-delimited key string
  @param value - Metric value
  @return table - Metric table with name, labels, and value
]]--
local function parse_metric(key, value)
    local parts = split_key(key)
    local metric = {labels = {}}
    local category = parts[1]

    if category == "connections" then
        metric.name = "nginx_connections_" .. parts[2]
        metric.value = value

    elseif category == "requests" then
        metric.name = "nginx_requests_" .. parts[2]
        metric.value = value

    elseif category == "server_zones" then
        parse_server_zone(parts, value, metric)

    elseif category == "upstreams" then
        parse_upstream(parts, value, metric)
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
