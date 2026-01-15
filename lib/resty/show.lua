local _M = {}

local common = require "stats.common"
local cjson = require "cjson.safe"

function _M.run()
    local stats = ngx.shared.ngx_stats
    local keys = stats:get_keys()
    local response = {}

    for k,v in pairs(keys) do
        response = common.format_response(v, stats:get(v), response)
    end

    ngx.header.content_type = "application/json"
    ngx.say(cjson.encode(response))
end

-- Execute when loaded as a script
_M.run()

return _M
