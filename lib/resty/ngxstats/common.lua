--[[
  Common utilities for lua-resty-ngxstats

  This module provides core utility functions for metrics collection,
  including shared memory operations, key formatting, and response formatting.
]]--

local _M = {}

--[[
  Split a string by a pattern
  @param str - The string to split
  @param pat - The pattern to split by
  @return table - Array of string segments
]]--
local function split(str, pat)
   local t = {}  -- NOTE: use {n = 0} in Lua-5.0
   local fpat = "(.-)" .. pat
   local last_end = 1
   local s, e, cap = str:find(fpat, 1)
   while s do
       if s ~= 1 or cap ~= "" then
           table.insert(t,cap)
       end
       last_end = e+1
       s, e, cap = str:find(fpat, last_end)
   end
   if last_end <= #str then
       cap = str:sub(last_end)
       table.insert(t, cap)
   end
   return t
end

--[[
  Increment a shared memory counter or create it if it doesn't exist
  @param stats - The shared memory dictionary (ngx.shared.DICT)
  @param key - The key to increment (string)
  @param count - The amount to increment by (number)
  @return number|nil, string|nil - The new value or nil and error message
]]--
function _M.incr_or_create(stats, key, count)
    local newval, err = stats:incr(key, count)
    if not newval and err == "not found" then
        local ok, add_err = stats:add(key, 0)
        if not ok then
            _M.errlog("Failed to add key ", key, ": ", add_err)
            return nil, add_err
        end
        newval, err = stats:incr(key, count)
        if not newval then
            _M.errlog("Failed to increment key ", key, ": ", err)
            return nil, err
        end
    elseif not newval then
        _M.errlog("Failed to increment key ", key, ": ", err)
        return nil, err
    end
    return newval
end

--[[
  Construct a colon-delimited key from an array of segments
  @param key_table - Array of key segments (e.g., {"server_zones", "default", "requests"})
  @return string - Colon-delimited key (e.g., "server_zones:default:requests")
]]--
function _M.key(key_table)
    return table.concat(key_table, ':')
end

--[[
  Check if a value exists in a table
  @param value - The value to search for
  @param table - The table to search in
  @return boolean - True if value is found, false otherwise
]]--
function _M.in_table(value, table)
    for _, v in pairs(table) do
        if (v == value) then
            return true
        end
    end
    return false
end

--[[
  Find a pattern match in a table
  @param value - The pattern to search for
  @param table - The table to search in
  @return boolean - True if pattern is found in any table value
]]--
function _M.find_in_table(value, table)
    for _, v in pairs(table) do
        if string.find(v, value) then
            return true
        end
    end
    return false
end

--[[
  Convert flat colon-delimited keys into nested JSON structure
  Recursively transforms "server_zones:default:requests" with value 100
  into {server_zones: {default: {requests: 100}}}

  @param key - Colon-delimited key string or remaining key segments
  @param value - The metric value
  @param response - The response table being built
  @return table - Updated response table with nested structure
]]--
function _M.format_response(key, value, response)
    local path = split(tostring(key), ':')
    key = table.remove(path, 1)
    if key == nil or key == '' then
         return value
    elseif response[key] == nil then
        response[key] = _M.format_response(_M.key(path), value, {})
    elseif response[key] ~= nil then
        response[key] = _M.format_response(_M.key(path), value, response[key])
    end
    return response
end

--[[
  Get the HTTP status code class (1xx, 2xx, 3xx, 4xx, 5xx)
  @param status - HTTP status code as string (e.g., "200", "404")
  @return string - Status code class (e.g., "2xx", "4xx")
]]--
function _M.get_status_code_class(status)
  if     status:sub(1,1) == '1' then
      return "1xx"
  elseif status:sub(1,1) == '2' then
      return "2xx"
  elseif status:sub(1,1) == '3' then
      return "3xx"
  elseif status:sub(1,1) == '4' then
      return "4xx"
  elseif status:sub(1,1) == '5' then
      return "5xx"
  else
      return "xxx"
  end
end

--[[
  Update a numeric value in shared memory (replace, not increment)
  @param stats - The shared memory dictionary
  @param key - The key to update
  @param value - The new numeric value
]]--
function _M.update_num(stats, key, value)
    stats:set(key, tonumber(value))
end

--[[
  Update a string value in shared memory (replace, not increment)
  @param stats - The shared memory dictionary
  @param key - The key to update
  @param value - The new string value
]]--
function _M.update_str(stats, key, value)
    stats:set(key, tostring(value))
end

--[[
  Safe conversion to number with default value
  @param value - Value to convert
  @param default - Default value if conversion fails (defaults to 0)
  @return number - Converted number or default
]]--
function _M.safe_tonumber(value, default)
    if value == nil or value == "" then
        return default or 0
    end
    local num = tonumber(value)
    return num or default or 0
end

--[[
  Safe conversion to string with default value
  @param value - Value to convert
  @param default - Default value if nil (defaults to "")
  @return string - Converted string or default
]]--
function _M.safe_tostring(value, default)
    if value == nil then
        return default or ""
    end
    return tostring(value)
end

local log_sign = "ngxstats"

--[[
  Log an error message with the ngxstats prefix
  @param ... - Variable arguments to log
]]--
function _M.errlog(...)
	ngx.log(ngx.ERR,log_sign,' ',...)
end


--[[
  Log an info message with the ngxstats prefix
  @param ... - Variable arguments to log
]]--
function _M.info(...)
	ngx.log(ngx.INFO,log_sign,' ',...)
end

return _M

