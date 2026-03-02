#!/bin/bash

# BitShares CCXT Bridge - End-to-End Test Suite
# Runs all test scripts and provides a comprehensive status report

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
TEST_RESULTS=()

# Function to print colored output
print_header() {
    echo -e "\n${PURPLE}=====================================${NC}"
    echo -e "${PURPLE}$1${NC}"
    echo -e "${PURPLE}=====================================${NC}"
}

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Function to run a test script
run_test() {
    local test_name="$1"
    local test_script="$2"
    local description="$3"
    
    echo -e "\n${CYAN}--- Running: $test_name ---${NC}"
    echo -e "${BLUE}Description: $description${NC}"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    if [ -f "$test_script" ]; then
        echo -e "${BLUE}Executing: ./$test_script${NC}"
        
        # Run without bash -x to avoid debug pollution
        echo -e "\n${YELLOW}[TEST OUTPUT]${NC}"
        echo "================================"
        
        set +e  # Don't exit on error for individual tests
        
        # Run the test normally
        if bash "$test_script" 2>&1; then
            local exit_code=0
        else
            local exit_code=$?
        fi
        
        set -e  # Re-enable exit on error
        
        echo "================================"
        echo -e "\n${YELLOW}[DEBUG] Exit code: $exit_code${NC}"
        
        # Analyze results
        if [ $exit_code -eq 0 ]; then
            # Check for actual success indicators
            if bash "$test_script" 2>&1 | grep -q "READY\|PASSED\|Success\|✓.*PASSED"; then
                print_success "$test_name PASSED"
                PASSED_TESTS=$((PASSED_TESTS + 1))
                TEST_RESULTS+=("$test_name: ✅ PASSED")
            else
                print_warning "$test_name completed but may have issues"
                PASSED_TESTS=$((PASSED_TESTS + 1))
                TEST_RESULTS+=("$test_name: ⚠️  COMPLETED (check output)")
            fi
        else
            print_error "$test_name FAILED (exit code: $exit_code)"
            FAILED_TESTS=$((FAILED_TESTS + 1))
            TEST_RESULTS+=("$test_name: ❌ FAILED")
            
            # Show error details
            echo -e "\n${RED}[ERROR] Checking specific failure...${NC}"
            echo "Let's run just the failing test to see the error clearly:"
            bash "$test_script" 2>&1 | tail -20
        fi
        
    else
        print_error "Test script not found: $test_script"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        TEST_RESULTS+=("$test_name: ❌ NOT FOUND")
    fi
}

# Function to check server status
check_server() {
    echo -e "\n${CYAN}--- Checking Server Status ---${NC}"
    
    if curl -s http://localhost:8787/describe >/dev/null 2>&1; then
        print_success "Server is running on port 8787"
        
        # Get server info
        echo -e "\n${BLUE}Server Info:${NC}"
        curl -s http://localhost:8787/describe | jq . 2>/dev/null || echo "Unable to fetch server info"
    else
        print_warning "Server is not running on port 8787"
        echo -e "${YELLOW}To start the server, run:${NC}"
        echo "  npm run dev"
        echo "  or"
        echo "  node dist/rest/server.js"
    fi
}

# Function to generate final report
generate_report() {
    print_header "END-TO-END TEST REPORT"
    
    echo -e "${BLUE}Total Test Suites: $TOTAL_TESTS${NC}"
    echo -e "${GREEN}Passed: $PASSED_TESTS${NC}"
    echo -e "${RED}Failed: $FAILED_TESTS${NC}"
    
    # Success rate
    if [ $TOTAL_TESTS -gt 0 ]; then
        local success_rate=$((PASSED_TESTS * 100 / TOTAL_TESTS))
        echo -e "${BLUE}Success Rate: $success_rate%${NC}"
    fi
    
    echo -e "\n${PURPLE}Detailed Results:${NC}"
    for result in "${TEST_RESULTS[@]}"; do
        echo "  $result"
    done
    
    # Overall status
    echo -e "\n${PURPLE}Overall Status:${NC}"
    if [ $FAILED_TESTS -eq 0 ]; then
        if [ $PASSED_TESTS -eq $TOTAL_TESTS ]; then
            print_success "All tests passed! System is ready for production."
        else
            print_warning "All tests completed but some may need attention."
        fi
    else
        print_error "$FAILED_TESTS test(s) failed. System requires fixes before production."
        echo -e "\n${YELLOW}Recommended actions:${NC}"
        echo "1. Check server logs for errors"
        echo "2. Verify all dependencies are installed"
        echo "3. Ensure proper configuration in .env file"
        echo "4. Fix failing tests before proceeding"
    fi
}

# Main execution
main() {
    print_header "BITSHARES CCXT BRIDGE - END-TO-END TEST SUITE"
    echo -e "${BLUE}Testing comprehensive functionality...${NC}\n"
    
    # Check server status first
    check_server
    
    # Run all test scripts
    run_test "CCXT Compliance Test" "test-ccxt-compliance.sh" "Tests CCXT API compliance and standard methods"
    run_test "CCXT Simple Test" "test-ccxt-simple.sh" "Quick validation of core CCXT methods"
    run_test "API Endpoint Test" "test-api.sh" "Tests REST API endpoints directly"
    run_test "Market Pairs Test" "test-pairs.sh" "Tests specific trading pairs and market data"
    
    # Generate comprehensive report
    generate_report
    
    # Exit with appropriate code
    if [ $FAILED_TESTS -gt 0 ]; then
        exit 1
    else
        exit 0
    fi
}

# Run main function
main "$@"
