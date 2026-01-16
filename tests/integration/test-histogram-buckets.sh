#!/bin/bash
# Test histogram bucket functionality
#
# Validates that histogram buckets are correctly populated

# Don't use set -e as run_test handles errors gracefully

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"

echo "Testing histogram bucket functionality..."

# Expected bucket boundaries - must be kept in sync with LATENCY_BUCKETS in:
# lib/resty/ngxstats/common.lua
# If bucket values change in common.lua, update this array accordingly.
EXPECTED_BUCKETS=("0.001" "0.005" "0.01" "0.025" "0.05" "0.1" "0.25" "0.5" "1" "2.5" "5" "10" "+Inf")

# Test: Histogram buckets exist for request time (at minimum +Inf and some lower buckets)
test_request_time_buckets_exist() {
    # Make some requests to ensure histogram is populated
    http_requests "${NGINX_URL}/hello" 10
    sleep 2

    local metrics
    metrics=$(fetch_metrics)

    # Check that +Inf bucket always exists (required for valid histogram)
    if ! echo "$metrics" | grep -q 'nginx_server_zone_request_time_seconds_bucket{.*le="+Inf"'; then
        echo "+Inf bucket is missing (required for valid histogram)"
        echo "Sample metrics with buckets:"
        echo "$metrics" | grep "request_time_seconds_bucket" | head -5
        return 1
    fi

    # Check that at least one non-Inf bucket exists
    local bucket_count
    bucket_count=$(echo "$metrics" | grep -c 'nginx_server_zone_request_time_seconds_bucket{' || echo "0")

    if [[ $bucket_count -lt 2 ]]; then
        echo "Expected at least 2 bucket entries (one regular + +Inf), found $bucket_count"
        return 1
    fi

    return 0
}

# Test: Buckets are cumulative (each bucket >= previous bucket)
test_buckets_are_cumulative() {
    # Make requests to populate histogram
    http_requests "${NGINX_URL}/hello" 20
    sleep 2

    local metrics
    metrics=$(fetch_metrics)

    local prev_value=0
    local bucket_order=("0.001" "0.005" "0.01" "0.025" "0.05" "0.1" "0.25" "0.5" "1" "2.5" "5" "10" "+Inf")

    for bucket in "${bucket_order[@]}"; do
        local value

        # Handle +Inf bucket specially
        if [[ "$bucket" == "+Inf" ]]; then
            value=$(echo "$metrics" | grep 'nginx_server_zone_request_time_seconds_bucket{.*le="+Inf"' | head -1 | awk '{print $NF}')
        else
            value=$(echo "$metrics" | grep "nginx_server_zone_request_time_seconds_bucket{.*le=\"${bucket}\"" | head -1 | awk '{print $NF}')
        fi
        value=${value:-0}

        if (( $(echo "$value < $prev_value" | bc -l) )); then
            echo "Bucket $bucket ($value) is less than previous bucket ($prev_value)"
            return 1
        fi

        prev_value=$value
    done

    return 0
}

# Test: +Inf bucket equals count metric
test_inf_bucket_equals_count() {
    http_requests "${NGINX_URL}/hello" 10
    sleep 2

    local metrics
    metrics=$(fetch_metrics)

    local inf_value
    inf_value=$(echo "$metrics" | grep 'nginx_server_zone_request_time_seconds_bucket{.*le="+Inf"' | head -1 | awk '{print $NF}')
    inf_value=${inf_value:-0}

    local count_value
    count_value=$(echo "$metrics" | grep 'nginx_server_zone_request_time_seconds_count{zone="' | head -1 | awk '{print $NF}')
    count_value=${count_value:-0}

    if [[ "$inf_value" == "$count_value" ]]; then
        return 0
    else
        echo "+Inf bucket ($inf_value) should equal count ($count_value)"
        return 1
    fi
}

# Test: Fast requests fall in small buckets
test_fast_requests_in_small_buckets() {
    # Make fast requests (simple hello endpoint should be < 100ms)
    for i in {1..20}; do
        curl -s "${NGINX_URL}/hello" > /dev/null
    done
    sleep 2

    local metrics
    metrics=$(fetch_metrics)

    # Check that requests landed in the 0.1s bucket (fast local requests should complete < 100ms)
    local small_bucket
    small_bucket=$(echo "$metrics" | grep 'nginx_server_zone_request_time_seconds_bucket{.*le="0.1"' | head -1 | awk '{print $NF}')
    small_bucket=${small_bucket:-0}

    # Should have at least some requests in the 0.1s bucket
    if [[ $small_bucket -gt 0 ]]; then
        return 0
    else
        echo "Expected some requests in 0.1s bucket, got $small_bucket"
        echo "Available buckets:"
        echo "$metrics" | grep 'nginx_server_zone_request_time_seconds_bucket{' | head -5
        return 1
    fi
}

# Test: Bucket le label format is correct
test_bucket_label_format() {
    http_requests "${NGINX_URL}/hello" 5
    sleep 1

    local metrics
    metrics=$(fetch_metrics)

    # Check that bucket labels use le= format (exclude comment lines)
    local bucket_lines
    bucket_lines=$(echo "$metrics" | grep "nginx_server_zone_request_time_seconds_bucket" | grep -v "^#")

    if [[ -z "$bucket_lines" ]]; then
        echo "No bucket metrics found"
        return 1
    fi

    # All bucket metric lines should have le="value" format
    local invalid_lines
    invalid_lines=$(echo "$bucket_lines" | grep -v 'le="[^"]*"' || true)

    if [[ -n "$invalid_lines" ]]; then
        echo "Found bucket lines without proper le label:"
        echo "$invalid_lines"
        return 1
    fi

    return 0
}

# Test: Buckets have correct TYPE
test_bucket_type_is_counter() {
    http_requests "${NGINX_URL}/hello" 5
    sleep 1

    local metrics
    metrics=$(fetch_metrics)

    # Histogram buckets should be type counter
    assert_metric_type "$metrics" "nginx_server_zone_request_time_seconds_bucket" "counter"
}

# Test: Sum and count exist alongside buckets
test_histogram_sum_and_count_exist() {
    http_requests "${NGINX_URL}/hello" 5
    sleep 1

    local metrics
    metrics=$(fetch_metrics)

    # Check for sum metric
    assert_metric_exists "$metrics" "nginx_server_zone_request_time_seconds_sum"

    # Check for count metric
    assert_metric_exists "$metrics" "nginx_server_zone_request_time_seconds_count"
}

# Test: Histogram count is properly incremented
test_histogram_count_increases() {
    # Make several requests to ensure histogram is populated
    http_requests "${NGINX_URL}/hello" 20
    sleep 2

    local metrics
    metrics=$(fetch_metrics)

    local count
    count=$(echo "$metrics" | grep 'nginx_server_zone_request_time_seconds_count{zone="' | head -1 | awk '{print $NF}')
    count=${count:-0}

    # Should have recorded some requests in the histogram
    if [[ $count -gt 0 ]]; then
        return 0
    else
        echo "Expected histogram count > 0, got $count"
        return 1
    fi
}

# Test: Zone label is present on all histogram metrics
test_histogram_zone_labels() {
    http_requests "${NGINX_URL}/hello" 5
    sleep 1

    local metrics
    metrics=$(fetch_metrics)

    # All request time metrics should have zone label (exclude comment lines)
    local bucket_lines
    bucket_lines=$(echo "$metrics" | grep "nginx_server_zone_request_time_seconds_bucket" | grep -v "^#")

    local lines_without_zone
    lines_without_zone=$(echo "$bucket_lines" | grep -v 'zone="' || true)

    if [[ -n "$lines_without_zone" ]]; then
        echo "Found bucket metrics without zone label:"
        echo "$lines_without_zone"
        return 1
    fi

    return 0
}

# Run all tests
run_test "Request time buckets exist" test_request_time_buckets_exist
run_test "Buckets are cumulative" test_buckets_are_cumulative
run_test "+Inf bucket equals count" test_inf_bucket_equals_count
run_test "Fast requests in small buckets" test_fast_requests_in_small_buckets
run_test "Bucket label format correct" test_bucket_label_format
run_test "Bucket type is counter" test_bucket_type_is_counter
run_test "Sum and count exist" test_histogram_sum_and_count_exist
run_test "Count increases with requests" test_histogram_count_increases
run_test "Zone labels on histogram metrics" test_histogram_zone_labels

print_summary
