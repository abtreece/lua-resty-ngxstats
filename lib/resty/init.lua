cjson = require "cjson.safe"
common = require "stats.common"
cache_status = {"MISS", "BYPASS", "EXPIRED", "STALE", "UPDATING", "REVALIDATED", "HIT"}
query_method = {"GET", "HEAD", "PUT", "POST", "DELETE", "OPTIONS"}

local stats = ngx.shared.ngx_stats
ngx.update_time()
