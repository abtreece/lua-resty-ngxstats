local _M = {}

local common = require "resty.ngxstats.common"

-- Record SSL/TLS metrics for a server zone
local function record_ssl_metrics(stats, group, ssl_protocol, ssl_cipher, ssl_session_reused)
    if ssl_protocol then
        common.incr_or_create(stats, common.key({'server_zones', group, 'ssl', 'protocol', ssl_protocol}), 1)
    end
    if ssl_cipher then
        common.incr_or_create(stats, common.key({'server_zones', group, 'ssl', 'cipher', ssl_cipher}), 1)
    end
    if ssl_session_reused then
        local session_type = ssl_session_reused == "r" and 'session_reused' or 'session_new'
        common.incr_or_create(stats, common.key({'server_zones', group, 'ssl', session_type}), 1)
    end
end

-- Record upstream timing and transfer metrics
local function record_upstream_metrics(stats, upstream_name, ctx)
    common.incr_or_create(stats, common.key({'upstreams', upstream_name, 'requests'}), 1)

    -- Response time sum and histogram
    common.incr_or_create(stats, common.key({'upstreams', upstream_name, 'response_time_sum'}),
        ctx.response_time)
    common.incr_or_create(stats, common.key({'upstreams', upstream_name, 'response_time_count'}), 1)
    common.record_histogram(stats,
        common.key({'upstreams', upstream_name, 'response_time_bucket'}), ctx.response_time)

    -- Other timing metrics
    common.incr_or_create(stats, common.key({'upstreams', upstream_name, 'queue_time'}),
        (ctx.queue_time or 0))
    common.incr_or_create(stats, common.key({'upstreams', upstream_name, 'connect_time'}),
        (ctx.connect_time or 0))

    -- Header time (time to first byte)
    if ctx.header_time and ctx.header_time > 0 then
        common.incr_or_create(stats, common.key({'upstreams', upstream_name, 'header_time_sum'}),
            ctx.header_time)
        common.incr_or_create(stats, common.key({'upstreams', upstream_name, 'header_time_count'}), 1)
    end

    -- Bytes transferred
    common.incr_or_create(stats, common.key({'upstreams', upstream_name, 'sent'}),
        common.safe_tonumber(ngx.var.upstream_bytes_sent))
    common.incr_or_create(stats, common.key({'upstreams', upstream_name, 'received'}),
        common.safe_tonumber(ngx.var.upstream_bytes_received))

    -- Response status tracking
    common.incr_or_create(stats,
        common.key({'upstreams', upstream_name, 'responses', common.get_status_code_class(ctx.status)}), 1)
    common.incr_or_create(stats, common.key({'upstreams', upstream_name, 'responses', ctx.status}), 1)
    common.incr_or_create(stats, common.key({'upstreams', upstream_name, 'responses', 'total'}), 1)

    -- Track per-server metrics when upstream_addr is available
    if ctx.addr ~= "" then
        local server_key = string.gsub(ctx.addr, "[%.:]", "_")
        common.incr_or_create(stats,
            common.key({'upstreams', upstream_name, 'servers', server_key, 'requests'}), 1)
        common.incr_or_create(stats,
            common.key({'upstreams', upstream_name, 'servers', server_key, 'response_time'}),
            ctx.response_time)
        common.update_str(stats, common.key({'upstreams', upstream_name, 'server'}), ctx.addr)
    end
end

function _M.run()
    ngx.update_time()
    local stats = ngx.shared.ngx_stats
    local cache_status = package.loaded['resty.ngxstats.cache_status']

    -- Validate and safely convert input values
    local status = common.safe_tostring(ngx.status, "0")
    local upstream_addr = common.safe_tostring(ngx.var.upstream_addr, "")
    local proxy_host = common.safe_tostring(ngx.var.proxy_host, "")
    local upstream_status = common.safe_tostring(ngx.var.upstream_status, "0")
    local server_name = common.safe_tostring(ngx.var.server_name, "")
    local request_method = common.safe_tostring(ngx.req.get_method(), "GET")
    local upstream_cache_status = ngx.var.upstream_cache_status

    local upstream_name = string.gsub(proxy_host, "%.", "_")
    local group = string.gsub(server_name, "%.", "_")

    -- General stats
    local upstream_response_time = common.safe_tonumber(ngx.var.upstream_response_time)
    local request_time = common.safe_tonumber(ngx.var.request_time)

    -- Set default group, if it's not defined
    if group == "_" or group == "" then
        group = "default"
    end
    -- Set default upstream, if it's not defined
    if upstream_name == "" then
        upstream_name = "default"
    end

    -- GENERIC
    common.update_num(stats, common.key({'requests', 'current'}), ngx.var.connections_active)
    common.incr_or_create(stats, common.key({'requests', 'total'}), 1)

    -- SERVER_ZONES
    common.incr_or_create(stats, common.key({'server_zones', group, 'requests'}), 1)
    common.incr_or_create(stats, common.key({'server_zones', group, 'received'}),
        common.safe_tonumber(ngx.var.request_length))
    common.incr_or_create(stats, common.key({'server_zones', group, 'sent'}),
        common.safe_tonumber(ngx.var.bytes_sent))
    common.incr_or_create(stats,
        common.key({'server_zones', group, 'responses', common.get_status_code_class(status)}), 1)
    common.incr_or_create(stats, common.key({'server_zones', group, 'responses', status}), 1)
    common.incr_or_create(stats, common.key({'server_zones', group, 'responses', 'total'}), 1)

    -- Request method tracking
    common.incr_or_create(stats, common.key({'server_zones', group, 'methods', request_method}), 1)

    -- Request timing (sum and histogram)
    if request_time and request_time > 0 then
        common.incr_or_create(stats, common.key({'server_zones', group, 'request_time_sum'}), request_time)
        common.incr_or_create(stats, common.key({'server_zones', group, 'request_time_count'}), 1)
        common.record_histogram(stats,
            common.key({'server_zones', group, 'request_time_bucket'}), request_time)

        -- Slow request tracking
        if request_time > common.SLOW_REQUEST_THRESHOLD then
            common.incr_or_create(stats, common.key({'server_zones', group, 'slow_requests'}), 1)
        end
    end

    -- Request size histogram
    local request_length = common.safe_tonumber(ngx.var.request_length)
    if request_length and request_length > 0 then
        common.record_histogram(stats,
            common.key({'server_zones', group, 'request_length_bucket'}), request_length,
            common.REQUEST_SIZE_BUCKETS)
    end

    -- SSL/TLS metrics
    record_ssl_metrics(stats, group, ngx.var.ssl_protocol, ngx.var.ssl_cipher, ngx.var.ssl_session_reused)

    -- Rate limiting metrics
    local limit_req_status = ngx.var.limit_req_status
    if limit_req_status then
        common.incr_or_create(stats,
            common.key({'server_zones', group, 'limit_req', string.lower(limit_req_status)}), 1)
    end

    -- UPSTREAM
    -- Track upstream failures (proxy configured but no response time = failure)
    if proxy_host ~= "" and not upstream_response_time then
        common.incr_or_create(stats, common.key({'upstreams', upstream_name, 'failures'}), 1)
    end

    if upstream_response_time then
        record_upstream_metrics(stats, upstream_name, {
            response_time = upstream_response_time,
            queue_time = common.safe_tonumber(ngx.var.upstream_queue_time),
            connect_time = common.safe_tonumber(ngx.var.upstream_connect_time),
            header_time = common.safe_tonumber(ngx.var.upstream_header_time),
            status = upstream_status,
            addr = upstream_addr
        })
    end

    -- Update upstream health gauge (calculated from requests vs failures)
    if proxy_host ~= "" then
        local health = common.calculate_upstream_health(stats, upstream_name)
        common.update_num(stats, common.key({'upstreams', upstream_name, 'health'}), health)
    end

    -- CACHE
    if upstream_cache_status and cache_status and common.in_table(upstream_cache_status, cache_status) then
        local cache_status_lower = string.lower(upstream_cache_status)
        common.incr_or_create(stats, common.key({'server_zones', group, 'cache', cache_status_lower}), 1)
    end
end

-- Execute when loaded as a script
_M.run()

return _M
