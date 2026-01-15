local _M = {}

local common = require "stats.common"

local find = string.find
local select = select
local tonumber = tonumber

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

    -- Safe conversion to number with default value
    local function safe_tonumber(value, default)
        if value == nil or value == "" then
            return default or 0
        end
        local num = tonumber(value)
        return num or default or 0
    end

    local var = ngx.var
    local accepted, handled, total = select(3, find(res.body, "accepts handled requests\n (%d*) (%d*) (%d*)"))

    local connections_active = safe_tonumber(var.connections_active)
    local connections_reading = safe_tonumber(var.connections_reading)
    local connections_writing = safe_tonumber(var.connections_writing)
    local connections_waiting = safe_tonumber(var.connections_waiting)
    local connections_accepted = safe_tonumber(accepted)
    local connections_handled = safe_tonumber(handled)
    local total_requests = safe_tonumber(total)

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
