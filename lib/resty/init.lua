-- Init module - sets up shared configuration for ngxstats
-- This runs once when nginx starts via init_by_lua_file

local cache_status = {"MISS", "BYPASS", "EXPIRED", "STALE", "UPDATING", "REVALIDATED", "HIT"}

ngx.update_time()

-- Store cache_status in package for access by other modules
package.loaded['stats.cache_status'] = cache_status
