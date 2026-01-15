-- lua-resty-ngxstats
-- OpenResty/NGINX metrics collection and Prometheus exporter
--
-- This module is loaded once when nginx starts via init_by_lua_file

local _M = {
    _VERSION = require "resty.ngxstats.version"
}

-- Valid cache status values for upstream_cache_status tracking
local cache_status = {"MISS", "BYPASS", "EXPIRED", "STALE", "UPDATING", "REVALIDATED", "HIT"}

ngx.update_time()

-- Store cache_status in package for access by other modules
package.loaded['resty.ngxstats.cache_status'] = cache_status

return _M
