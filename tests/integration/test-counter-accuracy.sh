#!/bin/bash
# Test counter accuracy
#
# Validates that counters increment correctly and consistently

# Don't use set -e as run_test handles errors gracefully

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"

echo "Testing counter accuracy..."

# Test: Counters never decrease
test_counters_never_decrease() {
    local metrics_before
    metrics_before=$(fetch_metrics)

    local requests_before
    requests_before=$(get_metric_value "$metrics_before" "nginx_requests_total")
    requests_before=${requests_before:-0}

    # Make some requests
    http_requests "${NGINX_URL}/hello" 20
    sleep 1

    local metrics_after
    metrics_after=$(fetch_metrics)

    local requests_after
    requests_after=$(get_metric_value "$metrics_after" "nginx_requests_total")

    if (( $(echo "$requests_after >= $requests_before" | bc -l) )); then
        return 0
    else
        echo "Counter decreased! Before: $requests_before, After: $requests_after"
        return 1
    fi
}

# Test: Exact request count increment
test_exact_request_increment() {
    local metrics_before
    metrics_before=$(fetch_metrics)

    local total_before
    total_before=$(get_metric_value "$metrics_before" "nginx_requests_total")
    total_before=${total_before:-0}

    local zone_before
    zone_before=$(echo "$metrics_before" | grep 'nginx_server_zone_requests_total{zone="' | head -1 | awk '{print $NF}')
    zone_before=${zone_before:-0}

    # Make exactly 25 requests (sequential to ensure accuracy)
    for i in {1..25}; do
        curl -s "${NGINX_URL}/hello" > /dev/null
    done
    sleep 1

    local metrics_after
    metrics_after=$(fetch_metrics)

    local total_after
    total_after=$(get_metric_value "$metrics_after" "nginx_requests_total")

    local zone_after
    zone_after=$(echo "$metrics_after" | grep 'nginx_server_zone_requests_total{zone="' | head -1 | awk '{print $NF}')

    local total_diff=$((total_after - total_before))
    local zone_diff=$((zone_after - zone_before))

    # Allow for some variance due to health checks, but should be at least 25
    if [[ $total_diff -ge 25 ]] && [[ $zone_diff -ge 25 ]]; then
        return 0
    else
        echo "Expected increment of at least 25"
        echo "Total requests increment: $total_diff"
        echo "Zone requests increment: $zone_diff"
        return 1
    fi
}

# Test: Status code counters increment correctly
test_status_code_accuracy() {
    local metrics_before
    metrics_before=$(fetch_metrics)

    # Get initial 404 count
    local not_found_before
    not_found_before=$(echo "$metrics_before" | grep 'nginx_server_zone_responses_total{.*status="404"' | awk '{print $NF}' || echo "0")
    not_found_before=${not_found_before:-0}

    # Make exactly 10 requests that return 404
    for i in {1..10}; do
        curl -s "${NGINX_URL}/get/404" > /dev/null
    done
    sleep 1

    local metrics_after
    metrics_after=$(fetch_metrics)

    local not_found_after
    not_found_after=$(echo "$metrics_after" | grep 'nginx_server_zone_responses_total{.*status="404"' | awk '{print $NF}')
    not_found_after=${not_found_after:-0}

    local diff=$((not_found_after - not_found_before))

    if [[ $diff -ge 10 ]]; then
        return 0
    else
        echo "Expected 404 counter increment of at least 10, got $diff"
        echo "Before: $not_found_before, After: $not_found_after"
        return 1
    fi
}

# Test: Method counters increment correctly
test_method_counter_accuracy() {
    local metrics_before
    metrics_before=$(fetch_metrics)

    # Get initial GET count
    local get_before
    get_before=$(echo "$metrics_before" | grep 'nginx_server_zone_methods_total{.*method="GET"' | awk '{print $NF}' || echo "0")
    get_before=${get_before:-0}

    # Get initial POST count
    local post_before
    post_before=$(echo "$metrics_before" | grep 'nginx_server_zone_methods_total{.*method="POST"' | awk '{print $NF}' || echo "0")
    post_before=${post_before:-0}

    # Make 5 GET requests
    for i in {1..5}; do
        curl -s "${NGINX_URL}/hello" > /dev/null
    done

    # Make 3 POST requests
    for i in {1..3}; do
        curl -s -X POST "${NGINX_URL}/hello" > /dev/null
    done
    sleep 1

    local metrics_after
    metrics_after=$(fetch_metrics)

    local get_after
    get_after=$(echo "$metrics_after" | grep 'nginx_server_zone_methods_total{.*method="GET"' | awk '{print $NF}')
    get_after=${get_after:-0}

    local post_after
    post_after=$(echo "$metrics_after" | grep 'nginx_server_zone_methods_total{.*method="POST"' | awk '{print $NF}')
    post_after=${post_after:-0}

    local get_diff=$((get_after - get_before))
    local post_diff=$((post_after - post_before))

    if [[ $get_diff -ge 5 ]] && [[ $post_diff -ge 3 ]]; then
        return 0
    else
        echo "GET increment: expected >= 5, got $get_diff"
        echo "POST increment: expected >= 3, got $post_diff"
        return 1
    fi
}

# Test: Bytes counters increase
test_bytes_counter_increase() {
    local metrics_before
    metrics_before=$(fetch_metrics)

    local sent_before
    sent_before=$(echo "$metrics_before" | grep 'nginx_server_zone_bytes_sent{zone="' | head -1 | awk '{print $NF}')
    sent_before=${sent_before:-0}

    # Make requests that will send/receive data
    for i in {1..10}; do
        curl -s "${NGINX_URL}/hello" > /dev/null
    done
    sleep 1

    local metrics_after
    metrics_after=$(fetch_metrics)

    local sent_after
    sent_after=$(echo "$metrics_after" | grep 'nginx_server_zone_bytes_sent{zone="' | head -1 | awk '{print $NF}')

    if (( $(echo "$sent_after > $sent_before" | bc -l) )); then
        return 0
    else
        echo "Bytes sent should have increased"
        echo "Before: $sent_before, After: $sent_after"
        return 1
    fi
}

# Test: Request time metrics exist and have values
test_request_time_accumulation() {
    # Make requests to ensure timing metrics are populated
    http_requests "${NGINX_URL}/hello" 20
    sleep 2

    local metrics
    metrics=$(fetch_metrics)

    local time_count
    time_count=$(echo "$metrics" | grep 'nginx_server_zone_request_time_seconds_count{zone="' | head -1 | awk '{print $NF}')
    time_count=${time_count:-0}

    local time_sum
    time_sum=$(echo "$metrics" | grep 'nginx_server_zone_request_time_seconds_sum{zone="' | head -1 | awk '{print $NF}')
    time_sum=${time_sum:-0}

    # Verify count is > 0 (requests were timed)
    if [[ $time_count -gt 0 ]] && (( $(echo "$time_sum > 0" | bc -l) )); then
        return 0
    else
        echo "Request time metrics not accumulating correctly"
        echo "Count: $time_count (expected > 0)"
        echo "Sum: $time_sum (expected > 0)"
        return 1
    fi
}

# Test: Connection counters are consistent
test_connection_counter_consistency() {
    local metrics
    metrics=$(fetch_metrics)

    local accepted
    accepted=$(get_metric_value "$metrics" "nginx_connections_accepted")

    local handled
    handled=$(get_metric_value "$metrics" "nginx_connections_handled")

    # Handled should never exceed accepted
    if (( $(echo "$handled <= $accepted" | bc -l) )); then
        return 0
    else
        echo "Handled connections ($handled) exceeds accepted ($accepted)"
        return 1
    fi
}

# Test: Response total equals sum of status classes
test_response_total_consistency() {
    local metrics
    metrics=$(fetch_metrics)

    # Get response total (if it exists without status label)
    local response_total
    response_total=$(echo "$metrics" | grep 'nginx_server_zone_responses_total{zone="[^"]*"}' | head -1 | awk '{print $NF}')

    if [[ -z "$response_total" ]]; then
        # No aggregate total, that's fine - skip this test
        echo "No aggregate response total metric found (OK)"
        return 0
    fi

    # Sum up all status class counts
    local sum=0
    for class in "1xx" "2xx" "3xx" "4xx" "5xx"; do
        local count
        count=$(echo "$metrics" | grep "nginx_server_zone_responses_total{.*status=\"$class\"" | head -1 | awk '{print $NF}')
        count=${count:-0}
        sum=$((sum + count))
    done

    # Total should equal sum of classes (with some tolerance for concurrent requests)
    local diff=$((response_total - sum))
    if [[ ${diff#-} -le 5 ]]; then  # Allow 5 request tolerance
        return 0
    else
        echo "Response total ($response_total) doesn't match sum of classes ($sum)"
        return 1
    fi
}

# Run all tests
run_test "Counters never decrease" test_counters_never_decrease
run_test "Exact request increment" test_exact_request_increment
run_test "Status code accuracy" test_status_code_accuracy
run_test "Method counter accuracy" test_method_counter_accuracy
run_test "Bytes counter increase" test_bytes_counter_increase
run_test "Request time accumulation" test_request_time_accumulation
run_test "Connection counter consistency" test_connection_counter_consistency
run_test "Response total consistency" test_response_total_consistency

print_summary
