--[[
  Output handler for metrics endpoint

  Formats and outputs metrics in Prometheus text exposition format
]]--

local _M = {}

local prometheus = require "stats.prometheus"

function _M.run()
    local stats = ngx.shared.ngx_stats

    -- Generate Prometheus format output
    local output = prometheus.format(stats)

    ngx.header.content_type = "text/plain; version=0.0.4"
    ngx.say(output)
end

-- Execute when loaded as a script
_M.run()

return _M
