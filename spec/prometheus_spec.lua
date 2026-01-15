--[[
  Unit tests for lib/resty/prometheus.lua
]]--

describe("prometheus module", function()
    local prometheus
    local helpers
    local mock_stats

    before_each(function()
        package.loaded['stats.prometheus'] = nil
        package.loaded['stats.common'] = nil
        helpers = require "spec.helpers"
        prometheus = require "stats.prometheus"
        mock_stats = helpers.mock_shared_dict()
    end)

    after_each(function()
        if mock_stats then
            mock_stats:clear()
        end
    end)

    describe("format()", function()
        it("should format connection metrics", function()
            mock_stats:set("connections:active", 5)
            mock_stats:set("connections:accepted", 1000)

            local output = prometheus.format(mock_stats)

            assert.is_not_nil(output)
            assert.is_string(output)
            assert.matches("nginx_connections_active", output)
            assert.matches("nginx_connections_accepted", output)
            assert.matches("# TYPE", output)
            assert.matches("# HELP", output)
        end)

        it("should format request metrics", function()
            mock_stats:set("requests:total", 500)
            mock_stats:set("requests:current", 10)

            local output = prometheus.format(mock_stats)

            assert.matches("nginx_requests_total 500", output)
            assert.matches("nginx_requests_current 10", output)
        end)

        it("should format server zone metrics with labels", function()
            mock_stats:set("server_zones:default:requests", 100)
            mock_stats:set("server_zones:default:received", 5000)
            mock_stats:set("server_zones:default:sent", 10000)

            local output = prometheus.format(mock_stats)

            assert.matches('nginx_server_zone_requests_total{zone="default"} 100', output)
            assert.matches('nginx_server_zone_bytes_received{zone="default"} 5000', output)
            assert.matches('nginx_server_zone_bytes_sent{zone="default"} 10000', output)
        end)

        it("should format response metrics with status labels", function()
            mock_stats:set("server_zones:default:responses:200", 50)
            mock_stats:set("server_zones:default:responses:404", 5)
            mock_stats:set("server_zones:default:responses:2xx", 50)
            mock_stats:set("server_zones:default:responses:4xx", 5)

            local output = prometheus.format(mock_stats)

            assert.matches('nginx_server_zone_responses_total{status="200",zone="default"}', output)
            assert.matches('nginx_server_zone_responses_total{status="404",zone="default"}', output)
            assert.matches('nginx_server_zone_responses_total{status="2xx",zone="default"}', output)
            assert.matches('nginx_server_zone_responses_total{status="4xx",zone="default"}', output)
        end)

        it("should format method metrics", function()
            mock_stats:set("server_zones:default:methods:GET", 80)
            mock_stats:set("server_zones:default:methods:POST", 20)

            local output = prometheus.format(mock_stats)

            assert.matches('nginx_server_zone_methods_total{method="GET",zone="default"} 80', output)
            assert.matches('nginx_server_zone_methods_total{method="POST",zone="default"} 20', output)
        end)

        it("should format cache metrics", function()
            mock_stats:set("server_zones:default:cache:hit", 100)
            mock_stats:set("server_zones:default:cache:miss", 20)

            local output = prometheus.format(mock_stats)

            assert.matches('nginx_server_zone_cache_total{cache_status="hit",zone="default"} 100', output)
            assert.matches('nginx_server_zone_cache_total{cache_status="miss",zone="default"} 20', output)
        end)

        it("should format upstream metrics with labels", function()
            mock_stats:set("upstreams:example_com:requests", 50)
            mock_stats:set("upstreams:example_com:response_time", 5.5)
            mock_stats:set("upstreams:example_com:server", "192.168.1.1:8080")

            local output = prometheus.format(mock_stats)

            assert.matches('nginx_upstream_requests_total{upstream="example_com"} 50', output)
            assert.matches('nginx_upstream_response_time_seconds{upstream="example_com"} 5.5', output)
            assert.matches('nginx_upstream_server_info{server="192.168.1.1:8080",upstream="example_com"} 1', output)
        end)

        it("should include HELP and TYPE comments", function()
            mock_stats:set("connections:active", 5)

            local output = prometheus.format(mock_stats)

            assert.matches("# HELP nginx_connections_active", output)
            assert.matches("# TYPE nginx_connections_active gauge", output)
        end)

        it("should handle empty stats", function()
            local output = prometheus.format(mock_stats)

            assert.is_not_nil(output)
            assert.is_string(output)
        end)

        it("should separate metric families with blank lines", function()
            mock_stats:set("connections:active", 5)
            mock_stats:set("requests:total", 100)

            local output = prometheus.format(mock_stats)

            -- Should have blank lines between different metric families
            assert.matches("\n\n", output)
        end)

        it("should handle multiple zones", function()
            mock_stats:set("server_zones:zone1:requests", 100)
            mock_stats:set("server_zones:zone2:requests", 200)

            local output = prometheus.format(mock_stats)

            assert.matches('zone="zone1"', output)
            assert.matches('zone="zone2"', output)
        end)
    end)
end)
