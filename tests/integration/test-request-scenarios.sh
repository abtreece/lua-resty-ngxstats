#!/bin/bash
# Test request handling scenarios
#
# Validates that different request types are properly tracked

# Don't use set -e as run_test handles errors gracefully

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"

echo "Testing request handling scenarios..."

# Test: Requests are counted correctly
test_request_counting() {
    # Get initial count
    local metrics_before
    metrics_before=$(fetch_metrics)
    local count_before
    count_before=$(get_metric_value "$metrics_before" "nginx_requests_total")
    count_before=${count_before:-0}

    # Make 10 requests
    http_requests "${NGINX_URL}/hello" 10

    # Small delay for metrics to update
    sleep 1

    # Get new count
    local metrics_after
    metrics_after=$(fetch_metrics)
    local count_after
    count_after=$(get_metric_value "$metrics_after" "nginx_requests_total")

    local expected_min=$((count_before + 10))

    if (( $(echo "$count_after >= $expected_min" | bc -l) )); then
        return 0
    else
        echo "Expected at least $expected_min requests, got $count_after"
        return 1
    fi
}

# Test: Server zone request tracking
test_server_zone_requests() {
    local metrics_before
    metrics_before=$(fetch_metrics)

    # Find current count for default zone
    local zone_count_before
    zone_count_before=$(echo "$metrics_before" | grep 'nginx_server_zone_requests_total{zone="' | head -1 | awk '{print $NF}')
    zone_count_before=${zone_count_before:-0}

    # Make requests
    http_requests "${NGINX_URL}/hello" 5
    sleep 1

    local metrics_after
    metrics_after=$(fetch_metrics)
    local zone_count_after
    zone_count_after=$(echo "$metrics_after" | grep 'nginx_server_zone_requests_total{zone="' | head -1 | awk '{print $NF}')

    local expected_min=$((zone_count_before + 5))

    if (( $(echo "$zone_count_after >= $expected_min" | bc -l) )); then
        return 0
    else
        echo "Expected zone requests >= $expected_min, got $zone_count_after"
        return 1
    fi
}

# Test: 2xx status codes tracked
test_2xx_responses() {
    # Make requests that return 200
    http_requests "${NGINX_URL}/hello" 5
    http_requests "${NGINX_URL}/get" 5
    sleep 1

    local metrics
    metrics=$(fetch_metrics)

    # Check for 2xx class counter
    assert_matches "$metrics" 'nginx_server_zone_responses_total\{[^}]*status="2xx"' "Should track 2xx responses"
}

# Test: 4xx status codes tracked
test_4xx_responses() {
    # Make requests that return 404
    http_requests "${NGINX_URL}/get/404" 3
    sleep 1

    local metrics
    metrics=$(fetch_metrics)

    # Check for 4xx class counter and specific 404 counter
    assert_matches "$metrics" 'nginx_server_zone_responses_total\{[^}]*status="4xx"' "Should track 4xx responses"
    assert_matches "$metrics" 'nginx_server_zone_responses_total\{[^}]*status="404"' "Should track 404 responses"
}

# Test: 5xx status codes tracked
test_5xx_responses() {
    # Make requests that return 500
    http_requests "${NGINX_URL}/get/500" 3
    sleep 1

    local metrics
    metrics=$(fetch_metrics)

    # Check for 5xx class counter
    assert_matches "$metrics" 'nginx_server_zone_responses_total\{[^}]*status="5xx"' "Should track 5xx responses"
    assert_matches "$metrics" 'nginx_server_zone_responses_total\{[^}]*status="500"' "Should track 500 responses"
}

# Test: HTTP methods are tracked
test_http_method_tracking() {
    # Make GET request (default)
    curl -s "${NGINX_URL}/hello" > /dev/null

    # Make POST request
    curl -s -X POST "${NGINX_URL}/hello" > /dev/null

    # Make PUT request
    curl -s -X PUT "${NGINX_URL}/hello" > /dev/null

    sleep 1

    local metrics
    metrics=$(fetch_metrics)

    # Check for method counters
    assert_matches "$metrics" 'nginx_server_zone_methods_total\{[^}]*method="GET"' "Should track GET method"
}

# Test: Bytes sent tracking
test_bytes_sent() {
    # Make some requests
    http_requests "${NGINX_URL}/hello" 5
    sleep 1

    local metrics
    metrics=$(fetch_metrics)

    # Check bytes_sent metric exists and is > 0
    assert_metric_exists "$metrics" "nginx_server_zone_bytes_sent"

    local bytes_sent
    bytes_sent=$(echo "$metrics" | grep 'nginx_server_zone_bytes_sent{zone="' | head -1 | awk '{print $NF}')

    if (( $(echo "$bytes_sent > 0" | bc -l) )); then
        return 0
    else
        echo "Expected bytes_sent > 0, got $bytes_sent"
        return 1
    fi
}

# Test: Bytes received tracking
test_bytes_received() {
    # Make some requests with body
    curl -s -X POST -d "test data" "${NGINX_URL}/hello" > /dev/null
    sleep 1

    local metrics
    metrics=$(fetch_metrics)

    assert_metric_exists "$metrics" "nginx_server_zone_bytes_received"
}

# Test: Request timing metrics
test_request_timing() {
    # Make some requests
    http_requests "${NGINX_URL}/hello" 10
    sleep 1

    local metrics
    metrics=$(fetch_metrics)

    # Check for request time sum and count
    assert_metric_exists "$metrics" "nginx_server_zone_request_time_seconds_sum"
    assert_metric_exists "$metrics" "nginx_server_zone_request_time_seconds_count"
}

# Test: Request time histogram buckets
test_request_time_histogram() {
    # Make some requests
    http_requests "${NGINX_URL}/hello" 10
    sleep 1

    local metrics
    metrics=$(fetch_metrics)

    # Check for histogram bucket metrics
    assert_matches "$metrics" 'nginx_server_zone_request_time_seconds_bucket\{[^}]*le=' "Should have histogram buckets"

    # Check for +Inf bucket
    assert_matches "$metrics" 'nginx_server_zone_request_time_seconds_bucket\{[^}]*le="\+Inf"' "Should have +Inf bucket"
}

# Test: Multiple status codes in same zone
test_multiple_status_codes() {
    # Generate various status codes
    curl -s "${NGINX_URL}/get" > /dev/null        # 200
    curl -s "${NGINX_URL}/get/204" > /dev/null    # 204
    curl -s "${NGINX_URL}/get/302" > /dev/null    # 302
    curl -s "${NGINX_URL}/get/404" > /dev/null    # 404
    curl -s "${NGINX_URL}/get/500" > /dev/null    # 500
    sleep 1

    local metrics
    metrics=$(fetch_metrics)

    # Check multiple status classes exist
    assert_matches "$metrics" 'status="2xx"' "Should have 2xx responses"
    assert_matches "$metrics" 'status="3xx"' "Should have 3xx responses"
    assert_matches "$metrics" 'status="4xx"' "Should have 4xx responses"
    assert_matches "$metrics" 'status="5xx"' "Should have 5xx responses"
}

# Run all tests
run_test "Request counting" test_request_counting
run_test "Server zone request tracking" test_server_zone_requests
run_test "2xx response tracking" test_2xx_responses
run_test "4xx response tracking" test_4xx_responses
run_test "5xx response tracking" test_5xx_responses
run_test "HTTP method tracking" test_http_method_tracking
run_test "Bytes sent tracking" test_bytes_sent
run_test "Bytes received tracking" test_bytes_received
run_test "Request timing metrics" test_request_timing
run_test "Request time histogram" test_request_time_histogram
run_test "Multiple status codes" test_multiple_status_codes

print_summary
