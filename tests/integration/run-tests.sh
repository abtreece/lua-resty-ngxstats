#!/bin/bash
# Integration test runner for lua-resty-ngxstats
#
# Usage:
#   ./run-tests.sh           # Run all tests
#   ./run-tests.sh --no-cleanup  # Keep containers running after tests
#   ./run-tests.sh test-metrics-format.sh  # Run specific test file

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=test-helpers.sh
source "$SCRIPT_DIR/test-helpers.sh"

# Configuration
COMPOSE_FILE="$SCRIPT_DIR/docker-compose.yml"
CLEANUP=true
SPECIFIC_TEST=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --no-cleanup)
            CLEANUP=false
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS] [TEST_FILE]"
            echo ""
            echo "Options:"
            echo "  --no-cleanup    Keep containers running after tests"
            echo "  --help, -h      Show this help message"
            echo ""
            echo "If TEST_FILE is specified, only that test file will be run."
            exit 0
            ;;
        *)
            SPECIFIC_TEST="$1"
            shift
            ;;
    esac
done

# Cleanup function
cleanup() {
    if [[ "$CLEANUP" == "true" ]]; then
        log_info "Cleaning up containers..."
        docker compose -f "$COMPOSE_FILE" down -v --remove-orphans 2>/dev/null || true
    else
        log_warning "Containers left running (--no-cleanup specified)"
        log_info "To stop: docker compose -f $COMPOSE_FILE down"
    fi
}

# Set trap for cleanup
trap cleanup EXIT

# Main test execution
main() {
    echo "========================================"
    echo "  lua-resty-ngxstats Integration Tests"
    echo "========================================"
    echo ""

    # Check dependencies
    log_info "Checking dependencies..."
    for cmd in docker curl bc; do
        if ! command -v "$cmd" &> /dev/null; then
            log_error "Required command not found: $cmd"
            exit 1
        fi
    done
    log_success "All dependencies found"

    # Build and start services
    log_info "Building Docker image..."
    docker compose -f "$COMPOSE_FILE" build --quiet

    log_info "Starting services..."
    docker compose -f "$COMPOSE_FILE" up -d

    # Wait for services to be healthy
    if ! wait_for_services 60; then
        log_error "Services failed to start"
        docker compose -f "$COMPOSE_FILE" logs
        exit 1
    fi

    # Delay to ensure metrics are initialized and upstream is fully ready
    sleep 3

    echo ""
    echo "========================================"
    echo "         Running Test Suites"
    echo "========================================"

    # Track overall results
    TOTAL_TESTS=0
    TOTAL_PASSED=0
    TOTAL_FAILED=0
    FAILED_SUITES=()

    # Run test suites
    if [[ -n "$SPECIFIC_TEST" ]]; then
        # Run specific test
        test_files=("$SCRIPT_DIR/$SPECIFIC_TEST")
    else
        # Run all test files
        test_files=("$SCRIPT_DIR"/test-*.sh)
    fi

    for test_file in "${test_files[@]}"; do
        # Skip the helpers file
        [[ "$(basename "$test_file")" == "test-helpers.sh" ]] && continue

        if [[ -f "$test_file" && -x "$test_file" ]]; then
            echo ""
            log_info "Running: $(basename "$test_file")"
            echo "----------------------------------------"

            # Run the test suite and capture output
            local output
            if output=$("$test_file" 2>&1); then
                suite_result=0
            else
                suite_result=1
            fi

            # Display the output
            echo "$output"

            # Parse the TEST_RESULTS line from output
            local results_line
            results_line=$(echo "$output" | grep "^TEST_RESULTS:" | tail -1)

            if [[ -n "$results_line" ]]; then
                local run passed failed
                run=$(echo "$results_line" | cut -d: -f2)
                passed=$(echo "$results_line" | cut -d: -f3)
                failed=$(echo "$results_line" | cut -d: -f4)

                TOTAL_TESTS=$((TOTAL_TESTS + run))
                TOTAL_PASSED=$((TOTAL_PASSED + passed))
                TOTAL_FAILED=$((TOTAL_FAILED + failed))

                if [[ $failed -gt 0 ]]; then
                    FAILED_SUITES+=("$(basename "$test_file")")
                fi
            elif [[ $suite_result -ne 0 ]]; then
                FAILED_SUITES+=("$(basename "$test_file")")
            fi
        fi
    done

    # Print final summary
    echo ""
    echo "========================================"
    echo "       FINAL TEST SUMMARY"
    echo "========================================"
    echo "  Total Tests:  $TOTAL_TESTS"
    echo -e "  ${GREEN}Passed:${NC}       $TOTAL_PASSED"
    echo -e "  ${RED}Failed:${NC}       $TOTAL_FAILED"
    echo "========================================"

    if [[ ${#FAILED_SUITES[@]} -gt 0 ]]; then
        echo ""
        log_error "Failed test suites:"
        for suite in "${FAILED_SUITES[@]}"; do
            echo "  - $suite"
        done
    fi

    # Return exit code based on failures
    if [[ $TOTAL_FAILED -gt 0 ]]; then
        exit 1
    fi

    log_success "All integration tests passed!"
}

# Run main
main "$@"
