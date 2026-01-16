#!/bin/bash
# Test Prometheus metrics format and structure
#
# Validates that metrics output follows Prometheus text exposition format

# Don't use set -e as run_test handles errors gracefully

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"

echo "Testing Prometheus metrics format..."

# Fetch metrics once for all tests
METRICS=$(fetch_metrics)

# Test: Metrics endpoint returns 200
test_metrics_endpoint_accessible() {
    local status
    status=$(http_status "$METRICS_URL")
    assert_equals "200" "$status" "Metrics endpoint should return 200"
}

# Test: Output contains valid Prometheus format
test_prometheus_format() {
    # Refresh metrics to ensure we have data
    METRICS=$(fetch_metrics)

    # Check for at least one metric line (metric_name value format)
    # Prometheus format: metric_name{labels} value or metric_name value
    if echo "$METRICS" | grep -qE "^nginx_[a-z_]+(\{[^}]*\})? [0-9]"; then
        return 0
    else
        echo "No metrics found in Prometheus format"
        echo "First 10 lines of output:"
        echo "$METRICS" | head -10
        return 1
    fi
}

# Test: Connection metrics exist with correct types
test_connection_metrics_exist() {
    assert_metric_exists "$METRICS" "nginx_connections_active"
    assert_metric_type "$METRICS" "nginx_connections_active" "gauge"
    assert_metric_help "$METRICS" "nginx_connections_active"
}

test_connection_accepted_metric() {
    assert_metric_exists "$METRICS" "nginx_connections_accepted"
    assert_metric_type "$METRICS" "nginx_connections_accepted" "counter"
}

test_connection_handled_metric() {
    assert_metric_exists "$METRICS" "nginx_connections_handled"
    assert_metric_type "$METRICS" "nginx_connections_handled" "counter"
}

test_connection_reading_metric() {
    assert_metric_exists "$METRICS" "nginx_connections_reading"
    assert_metric_type "$METRICS" "nginx_connections_reading" "gauge"
}

test_connection_writing_metric() {
    assert_metric_exists "$METRICS" "nginx_connections_writing"
    assert_metric_type "$METRICS" "nginx_connections_writing" "gauge"
}

test_connection_idle_metric() {
    assert_metric_exists "$METRICS" "nginx_connections_idle"
    assert_metric_type "$METRICS" "nginx_connections_idle" "gauge"
}

# Test: Request metrics exist
test_requests_total_metric() {
    assert_metric_exists "$METRICS" "nginx_requests_total"
    assert_metric_type "$METRICS" "nginx_requests_total" "counter"
}

test_requests_current_metric() {
    assert_metric_exists "$METRICS" "nginx_requests_current"
    assert_metric_type "$METRICS" "nginx_requests_current" "gauge"
}

# Test: Server zone metrics structure
test_server_zone_requests_metric() {
    # Generate a request first to ensure server zone metrics exist
    http_get "${NGINX_URL}/hello" > /dev/null

    # Re-fetch metrics
    METRICS=$(fetch_metrics)

    assert_metric_exists "$METRICS" "nginx_server_zone_requests_total"
    assert_metric_type "$METRICS" "nginx_server_zone_requests_total" "counter"
}

# Test: Labels are correctly formatted
test_label_format() {
    # Server zone metrics should have zone label
    assert_matches "$METRICS" 'zone="[^"]*"' "Server zone metrics should have zone label"
}

# Test: HELP comments are present
test_help_comments() {
    # Count HELP comments
    local help_count
    help_count=$(echo "$METRICS" | grep -c "^# HELP" || true)

    if [[ $help_count -lt 5 ]]; then
        echo "Expected at least 5 HELP comments, found $help_count"
        return 1
    fi
    return 0
}

# Test: TYPE comments are present
test_type_comments() {
    # Count TYPE comments
    local type_count
    type_count=$(echo "$METRICS" | grep -c "^# TYPE" || true)

    if [[ $type_count -lt 5 ]]; then
        echo "Expected at least 5 TYPE comments, found $type_count"
        return 1
    fi
    return 0
}

# Test: Metric values are numeric
test_metric_values_numeric() {
    # Get all metric lines (not comments)
    local invalid_values
    invalid_values=$(echo "$METRICS" | grep -v "^#" | grep -v "^$" | grep -v " [0-9]" | grep -v " [0-9]*\.[0-9]*$" || true)

    if [[ -n "$invalid_values" ]]; then
        echo "Found metrics with non-numeric values:"
        echo "$invalid_values"
        return 1
    fi
    return 0
}

# Test: No duplicate metric definitions
test_no_duplicate_types() {
    local duplicates
    duplicates=$(echo "$METRICS" | grep "^# TYPE" | sort | uniq -d)

    if [[ -n "$duplicates" ]]; then
        echo "Found duplicate TYPE declarations:"
        echo "$duplicates"
        return 1
    fi
    return 0
}

# Run all tests
run_test "Metrics endpoint accessible" test_metrics_endpoint_accessible
run_test "Prometheus format valid" test_prometheus_format
run_test "Connection active metric exists" test_connection_metrics_exist
run_test "Connection accepted metric" test_connection_accepted_metric
run_test "Connection handled metric" test_connection_handled_metric
run_test "Connection reading metric" test_connection_reading_metric
run_test "Connection writing metric" test_connection_writing_metric
run_test "Connection idle metric" test_connection_idle_metric
run_test "Requests total metric" test_requests_total_metric
run_test "Requests current metric" test_requests_current_metric
run_test "Server zone requests metric" test_server_zone_requests_metric
run_test "Label format correct" test_label_format
run_test "HELP comments present" test_help_comments
run_test "TYPE comments present" test_type_comments
run_test "Metric values numeric" test_metric_values_numeric
run_test "No duplicate TYPE declarations" test_no_duplicate_types

print_summary
