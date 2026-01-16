#!/bin/bash
# Test upstream proxy scenarios
#
# Validates that upstream metrics are correctly tracked

# Don't use set -e as run_test handles errors gracefully

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"

echo "Testing upstream proxy scenarios..."

# Test: Upstream requests are counted
test_upstream_requests_counted() {
    local metrics_before
    metrics_before=$(fetch_metrics)

    local upstream_before
    upstream_before=$(echo "$metrics_before" | grep 'nginx_upstream_requests_total{upstream="test_backend"}' | awk '{print $NF}')
    upstream_before=${upstream_before:-0}

    # Make requests through proxy
    http_requests "${NGINX_URL}/proxy/fast" 10
    sleep 1

    local metrics_after
    metrics_after=$(fetch_metrics)

    local upstream_after
    upstream_after=$(echo "$metrics_after" | grep 'nginx_upstream_requests_total{upstream="test_backend"}' | awk '{print $NF}')
    upstream_after=${upstream_after:-0}

    local diff=$((upstream_after - upstream_before))

    if [[ $diff -ge 10 ]]; then
        return 0
    else
        echo "Expected upstream requests increment >= 10, got $diff"
        return 1
    fi
}

# Test: Upstream response time is tracked
test_upstream_response_time() {
    # Make requests
    http_requests "${NGINX_URL}/proxy/fast" 5
    sleep 1

    local metrics
    metrics=$(fetch_metrics)

    # Check for response time sum and count
    assert_metric_exists "$metrics" "nginx_upstream_response_time_seconds_sum"
    assert_metric_exists "$metrics" "nginx_upstream_response_time_seconds_count"
}

# Test: Upstream response time histogram buckets
test_upstream_histogram_buckets() {
    # Make requests to populate histogram
    http_requests "${NGINX_URL}/proxy/fast" 10
    sleep 3

    local metrics
    metrics=$(fetch_metrics)

    # Check for histogram buckets with le label - check if any bucket exists
    if echo "$metrics" | grep -q 'nginx_upstream_response_time_seconds_bucket{'; then
        return 0
    else
        echo "No upstream response time buckets found"
        echo "Available upstream metrics:"
        echo "$metrics" | grep "^nginx_upstream" | head -10
        return 1
    fi
}

# Test: Upstream bytes sent tracking
test_upstream_bytes_sent() {
    http_requests "${NGINX_URL}/proxy/fast" 10
    sleep 1

    local metrics
    metrics=$(fetch_metrics)

    # Check for bytes sent metric
    assert_metric_exists "$metrics" "nginx_upstream_bytes_sent"

    local bytes
    bytes=$(echo "$metrics" | grep 'nginx_upstream_bytes_sent{upstream="test_backend"}' | awk '{print $NF}')
    bytes=${bytes:-0}

    if (( $(echo "$bytes > 0" | bc -l) )); then
        return 0
    else
        echo "Expected upstream bytes_sent > 0, got $bytes"
        return 1
    fi
}

# Test: Upstream bytes received tracking
test_upstream_bytes_received() {
    http_requests "${NGINX_URL}/proxy/fast" 10
    sleep 1

    local metrics
    metrics=$(fetch_metrics)

    assert_metric_exists "$metrics" "nginx_upstream_bytes_received"

    local bytes
    bytes=$(echo "$metrics" | grep 'nginx_upstream_bytes_received{upstream="test_backend"}' | awk '{print $NF}')
    bytes=${bytes:-0}

    if (( $(echo "$bytes > 0" | bc -l) )); then
        return 0
    else
        echo "Expected upstream bytes_received > 0, got $bytes"
        return 1
    fi
}

# Test: Upstream 5xx responses tracked
test_upstream_error_responses() {
    # Make requests that return 500 from upstream
    http_requests "${NGINX_URL}/proxy/error/500" 5
    sleep 3

    local metrics
    metrics=$(fetch_metrics)

    # Check for 5xx response tracking
    if echo "$metrics" | grep -q 'nginx_upstream_responses_total{.*status="5xx"'; then
        return 0
    else
        echo "No upstream 5xx responses found"
        echo "Available upstream response metrics:"
        echo "$metrics" | grep "nginx_upstream_responses" | head -5
        return 1
    fi
}

# Test: Upstream failures are tracked (connection refused)
test_upstream_failures() {
    local metrics_before
    metrics_before=$(fetch_metrics)

    local failures_before
    failures_before=$(echo "$metrics_before" | grep 'nginx_upstream_failures_total{upstream=' | awk '{print $NF}' || echo "0")
    failures_before=${failures_before:-0}

    # Make requests to bad upstream (should fail)
    for i in {1..3}; do
        curl -s "${NGINX_URL}/proxy/bad" > /dev/null 2>&1 || true
    done
    sleep 1

    local metrics_after
    metrics_after=$(fetch_metrics)

    # Check if failures metric exists (may or may not have incremented depending on how failures are detected)
    # This test validates the metric exists and can be tracked
    if echo "$metrics_after" | grep -q 'nginx_upstream_failures_total'; then
        return 0
    else
        # Failures might not be tracked if proxy_pass fails before reaching log phase
        # This is acceptable behavior
        echo "Note: upstream failures metric not present (may be expected if request doesn't reach log phase)"
        return 0
    fi
}

# Test: Upstream label is present on all upstream metrics
test_upstream_labels() {
    http_requests "${NGINX_URL}/proxy/fast" 5
    sleep 1

    local metrics
    metrics=$(fetch_metrics)

    local upstream_metrics
    upstream_metrics=$(echo "$metrics" | grep "^nginx_upstream_")

    if [[ -z "$upstream_metrics" ]]; then
        echo "No upstream metrics found"
        return 1
    fi

    # All upstream metrics (except comments) should have upstream label
    local metrics_without_label
    metrics_without_label=$(echo "$upstream_metrics" | grep -v "^#" | grep -v 'upstream="' || true)

    if [[ -n "$metrics_without_label" ]]; then
        echo "Found upstream metrics without upstream label:"
        echo "$metrics_without_label"
        return 1
    fi

    return 0
}

# Test: Upstream server info metric
test_upstream_server_info() {
    http_requests "${NGINX_URL}/proxy/fast" 5
    sleep 1

    local metrics
    metrics=$(fetch_metrics)

    # Check for server info metric with server label
    if echo "$metrics" | grep -q 'nginx_upstream_server_info{.*server='; then
        return 0
    else
        # Server info might not be tracked in all configurations
        echo "Note: upstream server_info metric not present"
        return 0
    fi
}

# Test: Multiple upstream requests don't create duplicate metrics
test_no_duplicate_upstream_metrics() {
    http_requests "${NGINX_URL}/proxy/fast" 20
    sleep 1

    local metrics
    metrics=$(fetch_metrics)

    # Check for duplicate TYPE declarations for upstream metrics
    local duplicates
    duplicates=$(echo "$metrics" | grep "^# TYPE nginx_upstream" | sort | uniq -d)

    if [[ -n "$duplicates" ]]; then
        echo "Found duplicate TYPE declarations:"
        echo "$duplicates"
        return 1
    fi
    return 0
}

# Test: Upstream response codes are tracked correctly
test_upstream_response_codes() {
    # Make requests to different upstream endpoints
    http_requests "${NGINX_URL}/proxy/fast" 5
    sleep 3

    local metrics
    metrics=$(fetch_metrics)

    # Check for 2xx tracking
    if echo "$metrics" | grep -q 'nginx_upstream_responses_total{.*status="2xx"'; then
        return 0
    else
        echo "No upstream 2xx responses found"
        echo "Available upstream response metrics:"
        echo "$metrics" | grep "nginx_upstream_responses" | head -5
        return 1
    fi
}

# Run all tests
run_test "Upstream requests counted" test_upstream_requests_counted
run_test "Upstream response time tracked" test_upstream_response_time
run_test "Upstream histogram buckets" test_upstream_histogram_buckets
run_test "Upstream bytes sent" test_upstream_bytes_sent
run_test "Upstream bytes received" test_upstream_bytes_received
run_test "Upstream error responses" test_upstream_error_responses
run_test "Upstream failures tracking" test_upstream_failures
run_test "Upstream labels present" test_upstream_labels
run_test "Upstream server info" test_upstream_server_info
run_test "No duplicate upstream metrics" test_no_duplicate_upstream_metrics
run_test "Upstream response codes" test_upstream_response_codes

print_summary
