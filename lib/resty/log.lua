ngx.update_time()
local stats = ngx.shared.ngx_stats;
local group = ngx.var.stats_group
local req_time = (tonumber(ngx.now() - ngx.req.start_time()) * 1000)
local status = tostring(ngx.status)
local request_method = ngx.req.get_method()

-- General stats
local upstream_response_time = tonumber(ngx.var.upstream_response_time)
local upstream_connect_time = tonumber(ngx.var.upstream_connect_time)
--local upstream_request_time = upstream_response_time - upstream_connect_time
local upstream_addr = ngx.var.upstream_addr
local upstream_status = ngx.var.upstream_status

-- Set default group, if it's not defined by nginx variable
if not group or group == "" then
    group = ngx.var.host
end

common.incr_or_create(stats, common.key({group, 'request', 'total'}), 1)
common.incr_or_create(stats, common.key({group, 'request', 'size'}), tonumber(ngx.var.request_length))

if req_time >= 0 and req_time < 100 then
    common.incr_or_create(stats, common.key({group, 'request', 'times', '0-100'}), 1)
elseif req_time >= 100 and req_time < 500 then
    common.incr_or_create(stats, common.key({group, 'request', 'times', '100-500'}), 1)
elseif req_time >= 500 and req_time < 1000 then 
    common.incr_or_create(stats, common.key({group, 'request', 'times', '500-1000'}), 1)
elseif req_time >= 1000 then
    common.incr_or_create(stats, common.key({group, 'request', 'times', '1000-inf'}), 1)
end

if upstream_response_time then
    common.incr_or_create(stats, common.key({group, 'upstream', 'requests'}), 1)
    common.incr_or_create(stats, common.key({group, 'upstream', 'response_time'}), (upstream_response_time or 0))
    common.incr_or_create(stats, common.key({group, 'upstream', 'connect_time'}), (upstream_connect_time or 0))
    --common.update(stats, common.key({group, 'upstream', 'request_time'}), (upstream_request_time or 0))
    common.update(stats, common.key({group, 'upstream', 'address'}), upstream_addr)
    common.incr_or_create(stats, common.key({group, 'upstream', 'responses', common.get_status_code_class(upstream_status)}), 1)
    common.incr_or_create(stats, common.key({group, 'upstream', 'responses', status}), 1)
    common.incr_or_create(stats, common.key({group, 'upstream', 'responses', 'total'}), 1)
end

if common.in_table(ngx.var.upstream_cache_status, cache_status) then
    local status = string.lower(ngx.var.upstream_cache_status)
    common.incr_or_create(stats, common.key({group, 'cache', status}), 1)
end

if common.in_table(request_method, query_method) then
    local method = string.lower(request_method)
    common.incr_or_create(stats, common.key({group, 'request_methods', method}), 1)
end

common.incr_or_create(stats, common.key({group, 'responses', status}), 1)
common.incr_or_create(stats, common.key({group, 'responses', common.get_status_code_class(status)}), 1)
common.incr_or_create(stats, common.key({group, 'responses', 'total'}), 1)

common.incr_or_create(stats, common.key({group, 'response', 'size'}), ngx.var.bytes_sent)

common.update(stats, common.key({'connections', 'active'}), ngx.var.connections_active)
common.update(stats, common.key({'connections', 'idle'}), ngx.var.connections_waiting)
common.update(stats, common.key({'connections', 'reading'}), ngx.var.connections_reading)
common.update(stats, common.key({'connections', 'writing'}), ngx.var.connections_writing)
common.update(stats, common.key({'connections', 'current'}), ngx.var.connection_requests)