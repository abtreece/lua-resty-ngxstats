--[[
  Unit tests for lib/resty/common.lua
]]--

describe("common module", function()
    local common
    local helpers
    local mock_stats

    -- Mock ngx for testing
    _G.ngx = {
        ERR = 4,
        INFO = 7,
        log = function(level, ...) end
    }

    before_each(function()
        package.loaded['stats.common'] = nil
        helpers = require "spec.helpers"
        common = require "stats.common"
        mock_stats = helpers.mock_shared_dict()
    end)

    after_each(function()
        if mock_stats then
            mock_stats:clear()
        end
    end)

    describe("key()", function()
        it("should create colon-delimited keys from arrays", function()
            local result = common.key({'server_zones', 'default', 'requests'})
            assert.equals("server_zones:default:requests", result)
        end)

        it("should handle single element arrays", function()
            local result = common.key({'connections'})
            assert.equals("connections", result)
        end)

        it("should handle empty arrays", function()
            local result = common.key({})
            assert.equals("", result)
        end)
    end)

    describe("incr_or_create()", function()
        it("should increment existing keys", function()
            mock_stats:add("test_key", 10)
            common.incr_or_create(mock_stats, "test_key", 5)
            assert.equals(15, mock_stats:get("test_key"))
        end)

        it("should create keys that don't exist", function()
            common.incr_or_create(mock_stats, "new_key", 5)
            assert.equals(5, mock_stats:get("new_key"))
        end)

        it("should handle zero increment", function()
            mock_stats:add("test_key", 10)
            common.incr_or_create(mock_stats, "test_key", 0)
            assert.equals(10, mock_stats:get("test_key"))
        end)

        it("should handle negative increment", function()
            mock_stats:add("test_key", 10)
            common.incr_or_create(mock_stats, "test_key", -3)
            assert.equals(7, mock_stats:get("test_key"))
        end)
    end)

    describe("update_num()", function()
        it("should set numeric values", function()
            common.update_num(mock_stats, "metric", 42)
            assert.equals(42, mock_stats:get("metric"))
        end)

        it("should overwrite existing values", function()
            mock_stats:set("metric", 10)
            common.update_num(mock_stats, "metric", 42)
            assert.equals(42, mock_stats:get("metric"))
        end)

        it("should convert strings to numbers", function()
            common.update_num(mock_stats, "metric", "123")
            assert.equals(123, mock_stats:get("metric"))
        end)
    end)

    describe("update_str()", function()
        it("should set string values", function()
            common.update_str(mock_stats, "server", "192.168.1.1")
            assert.equals("192.168.1.1", mock_stats:get("server"))
        end)

        it("should overwrite existing values", function()
            mock_stats:set("server", "old")
            common.update_str(mock_stats, "server", "new")
            assert.equals("new", mock_stats:get("server"))
        end)

        it("should convert numbers to strings", function()
            common.update_str(mock_stats, "server", 123)
            assert.equals("123", mock_stats:get("server"))
        end)
    end)

    describe("get_status_code_class()", function()
        it("should classify 1xx status codes", function()
            assert.equals("1xx", common.get_status_code_class("100"))
            assert.equals("1xx", common.get_status_code_class("101"))
        end)

        it("should classify 2xx status codes", function()
            assert.equals("2xx", common.get_status_code_class("200"))
            assert.equals("2xx", common.get_status_code_class("204"))
        end)

        it("should classify 3xx status codes", function()
            assert.equals("3xx", common.get_status_code_class("301"))
            assert.equals("3xx", common.get_status_code_class("302"))
        end)

        it("should classify 4xx status codes", function()
            assert.equals("4xx", common.get_status_code_class("404"))
            assert.equals("4xx", common.get_status_code_class("403"))
        end)

        it("should classify 5xx status codes", function()
            assert.equals("5xx", common.get_status_code_class("500"))
            assert.equals("5xx", common.get_status_code_class("503"))
        end)

        it("should handle unknown status codes", function()
            assert.equals("xxx", common.get_status_code_class("999"))
            assert.equals("xxx", common.get_status_code_class("abc"))
        end)
    end)

    describe("in_table()", function()
        it("should find values in tables", function()
            local t = {"GET", "POST", "PUT"}
            assert.is_true(common.in_table("GET", t))
            assert.is_true(common.in_table("POST", t))
        end)

        it("should return false for missing values", function()
            local t = {"GET", "POST", "PUT"}
            assert.is_false(common.in_table("DELETE", t))
        end)

        it("should handle empty tables", function()
            assert.is_false(common.in_table("GET", {}))
        end)
    end)

    describe("find_in_table()", function()
        it("should find pattern matches in tables", function()
            local t = {"example.com", "test.org", "demo.net"}
            assert.is_true(common.find_in_table("example", t))
            assert.is_true(common.find_in_table(".com", t))
        end)

        it("should return false for non-matching patterns", function()
            local t = {"example.com", "test.org"}
            assert.is_false(common.find_in_table("notfound", t))
        end)

        it("should handle empty tables", function()
            assert.is_false(common.find_in_table("test", {}))
        end)
    end)

    describe("format_response()", function()
        it("should convert flat keys to nested structure", function()
            local response = {}
            response = common.format_response("server_zones:default:requests", 100, response)

            assert.is_not_nil(response.server_zones)
            assert.is_not_nil(response.server_zones.default)
            assert.equals(100, response.server_zones.default.requests)
        end)

        it("should handle single-level keys", function()
            local response = {}
            response = common.format_response("requests", 50, response)
            assert.equals(50, response.requests)
        end)

        it("should merge multiple keys into same structure", function()
            local response = {}
            response = common.format_response("server_zones:default:requests", 100, response)
            response = common.format_response("server_zones:default:sent", 5000, response)

            assert.equals(100, response.server_zones.default.requests)
            assert.equals(5000, response.server_zones.default.sent)
        end)

        it("should handle deep nesting", function()
            local response = {}
            response = common.format_response("a:b:c:d:e", 42, response)

            assert.equals(42, response.a.b.c.d.e)
        end)
    end)
end)
