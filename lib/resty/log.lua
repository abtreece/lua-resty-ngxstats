local _M = {}

local common = require "stats.common"

-- Safe conversion to number with default value
local function safe_tonumber(value, default)
    if value == nil or value == "" then
        return default or 0
    end
    local num = tonumber(value)
    return num or default or 0
end

-- Safe conversion to string with default value
local function safe_tostring(value, default)
    if value == nil then
        return default or ""
    end
    return tostring(value)
end

function _M.run()
    ngx.update_time()
    local stats = ngx.shared.ngx_stats

    -- Validate and safely convert input values
    local status = safe_tostring(ngx.status, "0")
    local upstream_addr = safe_tostring(ngx.var.upstream_addr, "")
    local proxy_host = safe_tostring(ngx.var.proxy_host, "")
    local upstream_status = safe_tostring(ngx.var.upstream_status, "0")
    local server_name = safe_tostring(ngx.var.server_name, "")

    local upstream_name = string.gsub(proxy_host, "%.", "_")
    local group = string.gsub(server_name, "%.", "_")

    -- General stats
    local upstream_response_time = safe_tonumber(ngx.var.upstream_response_time)
    local upstream_queue_time = safe_tonumber(ngx.var.upstream_queue_time)
    local upstream_connect_time = safe_tonumber(ngx.var.upstream_connect_time)

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
    common.incr_or_create(stats, common.key({'server_zones', group, 'received'}), safe_tonumber(ngx.var.request_length))
    common.incr_or_create(stats, common.key({'server_zones', group, 'sent'}), safe_tonumber(ngx.var.bytes_sent))
    common.incr_or_create(stats, common.key({'server_zones', group, 'responses', common.get_status_code_class(status)}), 1)
    common.incr_or_create(stats, common.key({'server_zones', group, 'responses', status}), 1)
    common.incr_or_create(stats, common.key({'server_zones', group, 'responses', 'total'}), 1)

    -- UPSTREAM
    if upstream_response_time then
        common.incr_or_create(stats, common.key({'upstreams', upstream_name, 'requests'}), 1)
        common.incr_or_create(stats, common.key({'upstreams', upstream_name, 'response_time'}), (upstream_response_time or 0))
        common.incr_or_create(stats, common.key({'upstreams', upstream_name, 'queue_time'}), (upstream_queue_time or 0))
        common.incr_or_create(stats, common.key({'upstreams', upstream_name, 'connect_time'}), (upstream_connect_time or 0))
        common.incr_or_create(stats, common.key({'upstreams', upstream_name, 'sent'}), safe_tonumber(ngx.var.upstream_bytes_sent))
        common.incr_or_create(stats, common.key({'upstreams', upstream_name, 'received'}), safe_tonumber(ngx.var.upstream_bytes_received))
        common.incr_or_create(stats, common.key({'upstreams', upstream_name, 'responses', common.get_status_code_class(upstream_status)}), 1)
        common.incr_or_create(stats, common.key({'upstreams', upstream_name, 'responses', status}), 1)
        common.incr_or_create(stats, common.key({'upstreams', upstream_name, 'responses', 'total'}), 1)
        common.update_str(stats, common.key({'upstreams', upstream_name, 'server'}), upstream_addr)
    end

    -- CACHE
    --if common.in_table(ngx.var.upstream_cache_status, cache_status) then
    --    local status = string.lower(ngx.var.upstream_cache_status)
    --    common.incr_or_create(stats, common.key({'server_zones', group, 'cache', status}), 1)
    --end
end

-- Execute when loaded as a script
_M.run()

return _M
