local _M = {}

local common = require "stats.common"

local find = string.find
local select = select

function _M.run()
    local stats = ngx.shared.ngx_stats

    -- nginx stats
    local status_uri = "/nginx_status"
    local res = ngx.location.capture(status_uri)
    if not res or res.status ~= 200 then
      common.errlog("Failed to capture nginx_status: ", res and res.status or "nil response")
      ngx.status = 500
      ngx.say('{"error": "Failed to capture nginx status"}')
      return ngx.exit(500)
    end

    local var = ngx.var
    local accepted, handled = select(3, find(res.body, "accepts handled requests\n (%d*) (%d*) (%d*)"))

    local connections_active = common.safe_tonumber(var.connections_active)
    local connections_reading = common.safe_tonumber(var.connections_reading)
    local connections_writing = common.safe_tonumber(var.connections_writing)
    local connections_waiting = common.safe_tonumber(var.connections_waiting)
    local connections_accepted = common.safe_tonumber(accepted)
    local connections_handled = common.safe_tonumber(handled)

    -- CONNECTIONS
    common.update_num(stats, common.key({'connections', 'accepted'}), connections_accepted)
    common.update_num(stats, common.key({'connections', 'active'}), connections_active)
    common.update_num(stats, common.key({'connections', 'handled'}), connections_handled)
    common.update_num(stats, common.key({'connections', 'idle'}), connections_waiting)
    common.update_num(stats, common.key({'connections', 'reading'}), connections_reading)
    common.update_num(stats, common.key({'connections', 'writing'}), connections_writing)
end

-- Execute when loaded as a script
_M.run()

return _M
