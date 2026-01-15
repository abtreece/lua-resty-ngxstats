--[[
  Unit tests for lib/resty/ngxstats/prometheus.lua
]]--

describe("prometheus module", function()
    local prometheus
    local helpers
    local mock_stats

    before_each(function()
        package.loaded['resty.ngxstats.prometheus'] = nil
        package.loaded['resty.ngxstats.common'] = nil
        helpers = require "spec.helpers"
        prometheus = require "resty.ngxstats.prometheus"
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

            -- Label order may vary due to Lua table iteration, check that both labels exist
            assert.matches('nginx_server_zone_responses_total{[^}]*zone="default"[^}]*}', output)
            assert.matches('nginx_server_zone_responses_total{[^}]*status="200"[^}]*} 50', output)
            assert.matches('nginx_server_zone_responses_total{[^}]*status="404"[^}]*} 5', output)
            assert.matches('nginx_server_zone_responses_total{[^}]*status="2xx"[^}]*} 50', output)
            assert.matches('nginx_server_zone_responses_total{[^}]*status="4xx"[^}]*} 5', output)
        end)

        it("should format method metrics", function()
            mock_stats:set("server_zones:default:methods:GET", 80)
            mock_stats:set("server_zones:default:methods:POST", 20)

            local output = prometheus.format(mock_stats)

            -- Label order may vary due to Lua table iteration, check that both labels exist
            assert.matches('nginx_server_zone_methods_total{[^}]*zone="default"[^}]*}', output)
            assert.matches('nginx_server_zone_methods_total{[^}]*method="GET"[^}]*} 80', output)
            assert.matches('nginx_server_zone_methods_total{[^}]*method="POST"[^}]*} 20', output)
        end)

        it("should format cache metrics", function()
            mock_stats:set("server_zones:default:cache:hit", 100)
            mock_stats:set("server_zones:default:cache:miss", 20)

            local output = prometheus.format(mock_stats)

            -- Label order may vary due to Lua table iteration, check that both labels exist
            assert.matches('nginx_server_zone_cache_total{[^}]*zone="default"[^}]*}', output)
            assert.matches('nginx_server_zone_cache_total{[^}]*cache_status="hit"[^}]*} 100', output)
            assert.matches('nginx_server_zone_cache_total{[^}]*cache_status="miss"[^}]*} 20', output)
        end)

        it("should format upstream metrics with labels", function()
            mock_stats:set("upstreams:example_com:requests", 50)
            mock_stats:set("upstreams:example_com:response_time_sum", 5.5)
            mock_stats:set("upstreams:example_com:response_time_count", 10)
            mock_stats:set("upstreams:example_com:server", "192.168.1.1:8080")

            local output = prometheus.format(mock_stats)

            assert.matches('nginx_upstream_requests_total{upstream="example_com"} 50', output)
            assert.matches('nginx_upstream_response_time_seconds_sum{upstream="example_com"} 5.5', output)
            assert.matches('nginx_upstream_response_time_seconds_count{upstream="example_com"} 10', output)
            -- Label order may vary due to Lua table iteration, so check for both components
            assert.matches('nginx_upstream_server_info{.*server="192.168.1.1:8080"', output)
            assert.matches('nginx_upstream_server_info{.*upstream="example_com"', output)
        end)

        it("should format request time metrics", function()
            mock_stats:set("server_zones:default:request_time_sum", 12.345)
            mock_stats:set("server_zones:default:request_time_count", 100)

            local output = prometheus.format(mock_stats)

            assert.matches('nginx_server_zone_request_time_seconds_sum{zone="default"} 12.345', output)
            assert.matches('nginx_server_zone_request_time_seconds_count{zone="default"} 100', output)
            assert.matches('# TYPE nginx_server_zone_request_time_seconds_sum counter', output)
        end)

        it("should format SSL/TLS protocol metrics", function()
            mock_stats:set("server_zones:default:ssl:protocol:TLSv1.2", 100)
            mock_stats:set("server_zones:default:ssl:protocol:TLSv1.3", 50)

            local output = prometheus.format(mock_stats)

            -- Label order may vary, check for both labels
            assert.matches('nginx_server_zone_ssl_protocol_total{[^}]*zone="default"[^}]*}', output)
            assert.matches('nginx_server_zone_ssl_protocol_total{[^}]*protocol="TLSv1.2"[^}]*} 100', output)
            assert.matches('nginx_server_zone_ssl_protocol_total{[^}]*protocol="TLSv1.3"[^}]*} 50', output)
            assert.matches('# TYPE nginx_server_zone_ssl_protocol_total counter', output)
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

        it("should format histogram bucket metrics", function()
            mock_stats:set("server_zones:default:request_time_bucket:0.01", 50)
            mock_stats:set("server_zones:default:request_time_bucket:0.1", 80)
            mock_stats:set("server_zones:default:request_time_bucket:+Inf", 100)

            local output = prometheus.format(mock_stats)

            assert.matches('nginx_server_zone_request_time_seconds_bucket{[^}]*le="0.01"[^}]*} 50', output)
            assert.matches('nginx_server_zone_request_time_seconds_bucket{[^}]*le="0.1"[^}]*} 80', output)
            assert.matches('nginx_server_zone_request_time_seconds_bucket{[^}]*le="%+Inf"[^}]*} 100', output)
        end)

        it("should format SSL cipher metrics", function()
            mock_stats:set("server_zones:default:ssl:cipher:ECDHE-RSA-AES128-GCM-SHA256", 100)

            local output = prometheus.format(mock_stats)

            assert.matches('nginx_server_zone_ssl_cipher_total{[^}]*cipher="ECDHE%-RSA%-AES128%-GCM%-SHA256"', output)
        end)

        it("should format SSL session reuse metrics", function()
            mock_stats:set("server_zones:default:ssl:session_reused", 80)
            mock_stats:set("server_zones:default:ssl:session_new", 20)

            local output = prometheus.format(mock_stats)

            assert.matches('nginx_server_zone_ssl_sessions_total{[^}]*reused="true"[^}]*} 80', output)
            assert.matches('nginx_server_zone_ssl_sessions_total{[^}]*reused="false"[^}]*} 20', output)
        end)

        it("should format rate limit metrics", function()
            mock_stats:set("server_zones:default:limit_req:passed", 100)
            mock_stats:set("server_zones:default:limit_req:rejected", 5)

            local output = prometheus.format(mock_stats)

            assert.matches('nginx_server_zone_limit_req_total{[^}]*status="passed"[^}]*} 100', output)
            assert.matches('nginx_server_zone_limit_req_total{[^}]*status="rejected"[^}]*} 5', output)
        end)

        it("should format upstream failure metrics", function()
            mock_stats:set("upstreams:backend:failures", 10)

            local output = prometheus.format(mock_stats)

            assert.matches('nginx_upstream_failures_total{upstream="backend"} 10', output)
        end)

        it("should format upstream header time metrics", function()
            mock_stats:set("upstreams:backend:header_time_sum", 2.5)
            mock_stats:set("upstreams:backend:header_time_count", 100)

            local output = prometheus.format(mock_stats)

            assert.matches('nginx_upstream_header_time_seconds_sum{upstream="backend"} 2.5', output)
            assert.matches('nginx_upstream_header_time_seconds_count{upstream="backend"} 100', output)
        end)

        it("should format per-server upstream metrics", function()
            mock_stats:set("upstreams:backend:servers:192_168_1_1_8080:requests", 50)
            mock_stats:set("upstreams:backend:servers:192_168_1_1_8080:response_time", 5.5)

            local output = prometheus.format(mock_stats)

            assert.matches('nginx_upstream_server_requests_total{[^}]*server="192.168.1.1.8080"', output)
            assert.matches('nginx_upstream_server_response_time_seconds{[^}]*server="192.168.1.1.8080"', output)
        end)

        it("should format upstream response time histogram", function()
            mock_stats:set("upstreams:backend:response_time_bucket:0.05", 30)
            mock_stats:set("upstreams:backend:response_time_bucket:0.5", 80)
            mock_stats:set("upstreams:backend:response_time_bucket:+Inf", 100)

            local output = prometheus.format(mock_stats)

            assert.matches('nginx_upstream_response_time_seconds_bucket{[^}]*le="0.05"[^}]*} 30', output)
            assert.matches('nginx_upstream_response_time_seconds_bucket{[^}]*le="0.5"[^}]*} 80', output)
            assert.matches('nginx_upstream_response_time_seconds_bucket{[^}]*le="%+Inf"[^}]*} 100', output)
        end)
    end)
end)
