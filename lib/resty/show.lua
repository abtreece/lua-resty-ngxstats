local stats = ngx.shared.ngx_stats;
local keys = stats:get_keys()
local response = {}

--for k,v in pairs(keys) do print(k, stats:get(v)) end

for k,v in pairs(keys) do
    response = common.format_response(v, stats:get(v), response)
end

ngx.header.content_type = "application/json"
ngx.say(cjson.encode(response))
