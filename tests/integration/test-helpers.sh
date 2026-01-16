#!/bin/bash
# Test helpers and utilities for integration tests

# Don't use set -e as run_test handles errors gracefully

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test endpoints
NGINX_URL="${NGINX_URL:-http://localhost:18080}"
METRICS_URL="${METRICS_URL:-http://localhost:18081/status}"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $*"
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

# Test assertion functions
assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Values should be equal}"

    if [[ "$expected" == "$actual" ]]; then
        return 0
    else
        echo "Expected: '$expected'"
        echo "Actual:   '$actual'"
        return 1
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-String should contain substring}"

    if [[ "$haystack" == *"$needle"* ]]; then
        return 0
    else
        echo "String does not contain: '$needle'"
        return 1
    fi
}

assert_matches() {
    local string="$1"
    local pattern="$2"
    local message="${3:-String should match pattern}"

    if [[ "$string" =~ $pattern ]]; then
        return 0
    else
        echo "String does not match pattern: '$pattern'"
        return 1
    fi
}

assert_metric_exists() {
    local metrics="$1"
    local metric_name="$2"

    if echo "$metrics" | grep -q "^${metric_name}"; then
        return 0
    else
        echo "Metric not found: $metric_name"
        return 1
    fi
}

assert_metric_value() {
    local metrics="$1"
    local metric_pattern="$2"  # Expected to be a valid regex pattern
    local expected_value="$3"

    local line
    # Note: metric_pattern is used as a regex; caller must escape special chars if needed
    line=$(echo "$metrics" | grep -E "^${metric_pattern}" | head -1)

    if [[ -z "$line" ]]; then
        echo "Metric not found matching: $metric_pattern"
        return 1
    fi

    local actual_value
    actual_value=$(echo "$line" | awk '{print $NF}')

    if [[ "$actual_value" == "$expected_value" ]]; then
        return 0
    else
        echo "Metric: $metric_pattern"
        echo "Expected value: $expected_value"
        echo "Actual value: $actual_value"
        return 1
    fi
}

assert_metric_gte() {
    local metrics="$1"
    local metric_pattern="$2"  # Expected to be a valid regex pattern
    local min_value="$3"

    local line
    # Note: metric_pattern is used as a regex; caller must escape special chars if needed
    line=$(echo "$metrics" | grep -E "^${metric_pattern}" | head -1)

    if [[ -z "$line" ]]; then
        echo "Metric not found matching: $metric_pattern"
        return 1
    fi

    local actual_value
    actual_value=$(echo "$line" | awk '{print $NF}')

    if (( $(echo "$actual_value >= $min_value" | bc -l) )); then
        return 0
    else
        echo "Metric: $metric_pattern"
        echo "Expected >= $min_value"
        echo "Actual: $actual_value"
        return 1
    fi
}

assert_metric_type() {
    local metrics="$1"
    local metric_name="$2"
    local expected_type="$3"

    local type_line
    type_line=$(echo "$metrics" | grep "^# TYPE ${metric_name} ")

    if [[ -z "$type_line" ]]; then
        echo "TYPE comment not found for: $metric_name"
        return 1
    fi

    if [[ "$type_line" == *"$expected_type"* ]]; then
        return 0
    else
        echo "Expected type: $expected_type"
        echo "Found: $type_line"
        return 1
    fi
}

assert_metric_help() {
    local metrics="$1"
    local metric_name="$2"

    if echo "$metrics" | grep -q "^# HELP ${metric_name} "; then
        return 0
    else
        echo "HELP comment not found for: $metric_name"
        return 1
    fi
}

# Run a test function and track results
run_test() {
    local test_name="$1"
    local test_func="$2"

    TESTS_RUN=$((TESTS_RUN + 1))

    echo -n "  Testing: $test_name ... "

    local output
    local result
    output=$($test_func 2>&1) && result=0 || result=1

    if [[ $result -eq 0 ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log_success "PASSED"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        log_error "FAILED"
        if [[ -n "$output" ]]; then
            echo "$output" | sed 's/^/    /'
        fi
    fi

    return $result
}

# Make HTTP request and return status code
http_status() {
    local url="$1"
    curl -s -o /dev/null -w "%{http_code}" "$url"
}

# Make HTTP request and return body
http_get() {
    local url="$1"
    curl -s "$url"
}

# Make multiple requests to an endpoint
http_requests() {
    local url="$1"
    local count="${2:-10}"
    local concurrency="${3:-1}"

    for ((i=0; i<count; i++)); do
        curl -s -o /dev/null "$url" &
        if (( (i + 1) % concurrency == 0 )); then
            wait
        fi
    done
    wait
}

# Fetch current metrics
fetch_metrics() {
    curl -s "$METRICS_URL"
}

# Get a specific metric value
get_metric_value() {
    local metrics="$1"
    local metric_pattern="$2"

    echo "$metrics" | grep -E "^${metric_pattern}" | head -1 | awk '{print $NF}'
}

# Wait for services to be healthy
wait_for_services() {
    local timeout="${1:-60}"
    local elapsed=0

    log_info "Waiting for services to be healthy..."

    while [[ $elapsed -lt $timeout ]]; do
        if curl -sf "${METRICS_URL}" > /dev/null 2>&1; then
            log_success "Services are healthy"
            return 0
        fi
        sleep 1
        elapsed=$((elapsed + 1))
    done

    log_error "Timeout waiting for services after ${timeout}s"
    return 1
}

# Print test summary
print_summary() {
    echo ""
    echo "========================================"
    echo "          TEST SUMMARY"
    echo "========================================"
    echo "  Total:  $TESTS_RUN"
    echo -e "  ${GREEN}Passed:${NC} $TESTS_PASSED"
    echo -e "  ${RED}Failed:${NC} $TESTS_FAILED"
    echo "========================================"

    # Output results in parseable format for the runner
    echo "TEST_RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"

    if [[ $TESTS_FAILED -gt 0 ]]; then
        return 1
    fi
    return 0
}

# Export functions for use in test scripts
export -f log_info log_success log_error log_warning
export -f assert_equals assert_contains assert_matches
export -f assert_metric_exists assert_metric_value assert_metric_gte
export -f assert_metric_type assert_metric_help
export -f run_test http_status http_get http_requests
export -f fetch_metrics get_metric_value
export -f wait_for_services print_summary
