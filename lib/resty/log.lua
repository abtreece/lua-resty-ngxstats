ngx.update_time()
local stats = ngx.shared.ngx_stats
local req_time = (tonumber(ngx.now() - ngx.req.start_time()) * 1000)
local status = tostring(ngx.status)
--local request_method = ngx.req.get_method()
local upstream_addr = tostring(ngx.var.upstream_addr)
local proxy_host = tostring(ngx.var.proxy_host)
local upstream_status = ngx.var.upstream_status


--local request_path = string.gsub(ngx.var.uri, "%..*", "")
local upstream_name = string.gsub(proxy_host, "%.", "_")
local group = string.gsub(ngx.var.server_name, "%.", "_")

-- General stats
local upstream_response_time = tonumber(ngx.var.upstream_response_time)
local upstream_queue_time = tonumber(ngx.var.upstream_queue_time)
local upstream_connect_time = tonumber(ngx.var.upstream_connect_time)

-- Set default group, if it's not defined
if group == "_" or group == "" then
    group = "default"
end
-- Set default upstream, if it's not defined
if upstream_name == "" then
    upstream_name = "default"
end

-- GENERIC
common.update(stats, common.key({'requests', 'current'}), ngx.var.connections_active)
common.incr_or_create(stats, common.key({'requests', 'total'}), ngx.var.connections_active)

-- CONNECTIONS
--common.incr_or_create(stats, common.key({'connections', 'accepted'}), connections_accepted)
--common.update(stats, common.key({'connections', 'active'}), connections_active)
--common.update(stats, common.key({'connections', 'current'}), ngx.var.connection_requests)
--common.update(stats, common.key({'connections', 'handled'}), connections_handled)
--common.update(stats, common.key({'connections', 'idle'}), ngx.var.connections_waiting)
--common.update(stats, common.key({'connections', 'reading'}), connections_reading)
--common.update(stats, common.key({'connections', 'writing'}), connections_writing)

-- SERVER_ZONES
common.incr_or_create(stats, common.key({'server_zones', group, 'requests'}), 1)
common.incr_or_create(stats, common.key({'server_zones', group, 'received'}), tonumber(ngx.var.request_length))
common.incr_or_create(stats, common.key({'server_zones', group, 'sent'}), tonumber(ngx.var.bytes_sent))
common.incr_or_create(stats, common.key({'server_zones', group, 'responses', common.get_status_code_class(status)}), 1)
common.incr_or_create(stats, common.key({'server_zones', group, 'responses', status}), 1)
common.incr_or_create(stats, common.key({'server_zones', group, 'responses', 'total'}), 1)

--if common.in_table(request_method, query_method) then
--    local method = string.lower(request_method)
--    common.incr_or_create(stats, common.key({'server_zones', group, 'request_methods', method}), 1)
--end

--common.incr_or_create(stats, common.key({'server', group, 'paths', request_path}), 1)

-- UPSTREAM
if upstream_response_time then
    common.incr_or_create(stats, common.key({'upstreams', upstream_name, 'requests'}), 1)
    common.incr_or_create(stats, common.key({'upstreams', upstream_name, 'response_time'}), (upstream_response_time or 0))
    common.incr_or_create(stats, common.key({'upstreams', upstream_name, 'queue_time'}), (upstream_queue_time or 0))
    common.incr_or_create(stats, common.key({'upstreams', upstream_name, 'connect_time'}), (upstream_connect_time or 0))
    common.incr_or_create(stats, common.key({'upstreams', upstream_name, 'sent'}), tonumber(ngx.var.upstream_bytes_sent))
    common.incr_or_create(stats, common.key({'upstreams', upstream_name, 'received'}), tonumber(ngx.var.upstream_bytes_received))
    common.incr_or_create(stats, common.key({'upstreams', upstream_name, 'responses', common.get_status_code_class(upstream_status)}), 1)
    common.incr_or_create(stats, common.key({'upstreams', upstream_name, 'responses', status}), 1)
    common.incr_or_create(stats, common.key({'upstreams', upstream_name, 'responses', 'total'}), 1)
    common.update(stats, common.key({'upstreams', upstream_name, 'server'}), upstream_addr)

end

-- CACHE
if common.in_table(ngx.var.upstream_cache_status, cache_status) then
    local status = string.lower(ngx.var.upstream_cache_status)
    common.incr_or_create(stats, common.key({'server_zones', group, 'cache', status}), 1)
end
