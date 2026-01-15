local cjson = require "cjson.safe"
local common = require "stats.common"
local cache_status = {"MISS", "BYPASS", "EXPIRED", "STALE", "UPDATING", "REVALIDATED", "HIT"}
local query_method = {"GET", "HEAD", "PUT", "POST", "DELETE", "OPTIONS"}

local stats = ngx.shared.ngx_stats
ngx.update_time()

-- Store in package for access by other modules if needed
package.loaded['stats.cache_status'] = cache_status
