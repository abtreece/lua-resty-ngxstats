--[[
  Test helpers and mocks for busted tests
]]--

local _M = {}

-- Mock ngx.shared.DICT for testing
function _M.mock_shared_dict()
    local data = {}

    local dict = {
        get = function(self, key)
            return data[key]
        end,

        set = function(self, key, value)
            data[key] = value
            return true, nil
        end,

        add = function(self, key, value)
            if data[key] ~= nil then
                return false, "exists"
            end
            data[key] = value
            return true, nil
        end,

        incr = function(self, key, value)
            if data[key] == nil then
                return nil, "not found"
            end
            data[key] = data[key] + value
            return data[key], nil
        end,

        get_keys = function(self, max_count)
            local keys = {}
            for k, _ in pairs(data) do
                table.insert(keys, k)
            end
            return keys
        end,

        -- Helper to clear data between tests
        clear = function(self)
            data = {}
        end,

        -- Helper to inspect data
        dump = function(self)
            return data
        end
    }

    return dict
end

-- Mock ngx API for testing
function _M.mock_ngx()
    return {
        ERR = 4,
        INFO = 7,
        log = function(level, ...) end,
        say = function(...) end,
        exit = function(status) end,
        status = 200,
        header = {},
        var = {
            connections_active = "10",
            connections_reading = "1",
            connections_writing = "2",
            connections_waiting = "7",
            upstream_addr = "127.0.0.1:8080",
            proxy_host = "example.com",
            upstream_status = "200",
            server_name = "localhost",
            request_length = "100",
            bytes_sent = "500",
            upstream_response_time = "0.123",
            upstream_queue_time = "0.001",
            upstream_connect_time = "0.010",
            upstream_bytes_sent = "100",
            upstream_bytes_received = "500"
        },
        req = {
            get_method = function() return "GET" end
        },
        location = {
            capture = function(uri)
                return {
                    status = 200,
                    body = "Active connections: 10 \nserver accepts handled requests\n 100 100 1000 \nReading: 1 Writing: 2 Waiting: 7 \n"
                }
            end
        },
        shared = {},
        update_time = function() end,
        now = function() return os.time() end
    }
end

return _M
