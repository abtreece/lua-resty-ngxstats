local stats = ngx.shared.ngx_stats
local utils = require "stats.utils"
local common = require "stats.common"

local ngx = ngx
local find = string.find
local select = select
local tonumber = tonumber

local select = select
local tonumber = tonumber

-- nginx stats
local status_uri = "/nginx_status"
local res = ngx.location.capture(status_uri)
if res.status ~= 200 then
  return response.exit(500, { message = "An unexpected error happened" })
end

local var = ngx.var
local accepted, handled, total = select(3, find(res.body, "accepts handled requests\n (%d*) (%d*) (%d*)"))

local connections_active = tonumber(var.connections_active)
local connections_reading = tonumber(var.connections_reading)
local connections_writing = tonumber(var.connections_writing)
local connections_waiting = tonumber(var.connections_waiting)
local connections_accepted = tonumber(accepted)
local connections_handled = tonumber(handled)
local total_requests = tonumber(total)

-- CONNECTIONS
common.update_num(stats, common.key({'connections', 'accepted'}), connections_accepted)
common.update_num(stats, common.key({'connections', 'active'}), connections_active)
common.update_num(stats, common.key({'connections', 'handled'}), connections_handled)
common.update_num(stats, common.key({'connections', 'idle'}), connections_waiting)
common.update_num(stats, common.key({'connections', 'reading'}), connections_reading)
common.update_num(stats, common.key({'connections', 'writing'}), connections_writing)
