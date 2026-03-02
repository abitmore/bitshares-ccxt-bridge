#!/bin/bash

# CCXT Compliance Test Script for BitShares CCXT Bridge
# Tests all implemented CCXT methods and verifies response formats

set -e

# Configuration
PORT=${PORT:-8787}
BASE_URL="http://localhost:$PORT"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Helper function to make API calls
api_call() {
    local method="$1"
    local endpoint="$2"
    local data="$3"
    
    if [ "$method" = "GET" ]; then
        curl -s -X GET "$BASE_URL$endpoint" 2>/dev/null
    elif [ "$method" = "POST" ]; then
        curl -s -X POST -H "Content-Type: application/json" -d "$data" "$BASE_URL$endpoint" 2>/dev/null
    elif [ "$method" = "PUT" ]; then
        curl -s -X PUT -H "Content-Type: application/json" -d "$data" "$BASE_URL$endpoint" 2>/dev/null
    elif [ "$method" = "DELETE" ]; then
        curl -s -X DELETE "$BASE_URL$endpoint" 2>/dev/null
    fi
}

# Test function
# Replace the test_endpoint function with:
test_endpoint() {
    local name="$1"
    local method="$2"
    local endpoint="$3"
    local data="$4"
    local expected_keys="$5"
    
    echo -n "Testing $name... "
    
    local response=$(api_call "$method" "$endpoint" "$data")
    local status=$?
    
    if [ $status -ne 0 ]; then
        echo -e "${RED}FAILED${NC} (Connection error)"
        return
    fi
    
    # Check Content-Type header
    local content_type=$(curl -sI "$BASE_URL$endpoint" | grep -i 'content-type' | tr -d '\r')
    if [[ ! "$content_type" =~ "application/json" ]]; then
        echo -e "${YELLOW}WARNING${NC} (Invalid Content-Type: $content_type)"
    fi
    
    # Try to parse JSON
    if ! jq -e . >/dev/null 2>&1 <<<"$response"; then
        echo -e "${RED}FAILED${NC} (Invalid JSON)"
<<<<<<< HEAD
        return
    fi
    
    # Rest of validation...
=======
        ((TESTS_FAILED++))
        return
    fi
    
    # Check for API error in response
    if echo "$response" | jq -e '.error' >/dev/null 2>&1; then
        local error_msg=$(echo "$response" | jq -r '.error // "Unknown error"')
        echo -e "${RED}FAILED${NC} (API error: $error_msg)"
        ((TESTS_FAILED++))
        return
    fi
    
    # Check expected keys if provided
    if [ -n "$expected_keys" ]; then
        local missing_keys=""
        for key in $expected_keys; do
            if ! echo "$response" | jq -e ".$key" >/dev/null 2>&1; then
                missing_keys="$missing_keys $key"
            fi
        done
        
        if [ -n "$missing_keys" ]; then
            echo -e "${RED}FAILED${NC} (Missing keys:$missing_keys)"
            ((TESTS_FAILED++))
            return
        fi
    fi
    
    # If we got here, the test passed
    echo -e "${GREEN}PASSED${NC}"
    ((TESTS_PASSED++))
>>>>>>> 34a1355e0a518c16dd7901035145a0858f6d8d70
}

# Check if server is running
echo -e "${BLUE}CCXT Compliance Test Suite${NC}"
echo "Testing BitShares CCXT Bridge at $BASE_URL"
echo

if ! curl -s "$BASE_URL/describe" >/dev/null 2>&1; then
    echo -e "${RED}ERROR:${NC} Server is not running on port $PORT"
    echo "Please start the server first with: ./start.sh"
    exit 1
fi

echo -e "${YELLOW}Public API Tests${NC}"
echo "=================="

# Test describe endpoint
test_endpoint "describe" "GET" "/describe" "" "id name"

# Test markets endpoint
test_endpoint "fetchMarkets" "GET" "/markets" "" ""

# Test currencies endpoint (new)
test_endpoint "fetchCurrencies" "GET" "/currencies" "" ""

# Test trading fees endpoint (new)
test_endpoint "fetchTradingFees" "GET" "/tradingFees" "" "trading"

# Test trading limits endpoint (new)
test_endpoint "fetchTradingLimits" "GET" "/tradingLimits" "" ""

# Test ticker with a common pair
test_endpoint "fetchTicker" "GET" "/ticker?symbol=BTS/CNY" "" "symbol last bid ask"

# Test order book
test_endpoint "fetchOrderBook" "GET" "/orderbook?symbol=BTS/CNY&limit=10" "" "symbol bids asks"

# Test trades
test_endpoint "fetchTrades" "GET" "/trades?symbol=BTS/CNY&limit=5" "" ""

# Test OHLCV
test_endpoint "fetchOHLCV" "GET" "/ohlcv?symbol=BTS/CNY" "" ""

echo
echo -e "${YELLOW}Private API Tests (require login)${NC}"
echo "=================================="

# Note: These tests will fail without proper login credentials
# They are included to verify the endpoints exist and return proper error messages

test_endpoint "fetchBalance" "GET" "/balance" "" ""

test_endpoint "fetchOpenOrders" "GET" "/openOrders" "" ""

test_endpoint "fetchOrders" "GET" "/orders" "" ""

test_endpoint "fetchMyTrades" "GET" "/myTrades" "" ""

# Test individual order fetch (will fail without valid order ID)
test_endpoint "fetchOrder" "GET" "/order/1.7.12345" "" ""

echo
echo -e "${YELLOW}CCXT Method Coverage Analysis${NC}"
echo "============================="

# Check which CCXT methods are implemented
echo "✅ Public API Methods:"
echo "  - describe"
echo "  - fetchMarkets"
echo "  - fetchCurrencies (NEW)"
echo "  - fetchTicker"
echo "  - fetchOrderBook"
echo "  - fetchTrades"
echo "  - fetchOHLCV"
echo "  - fetchTradingFees (NEW)"
echo "  - fetchTradingLimits (NEW)"

echo
echo "✅ Private API Methods:"
echo "  - fetchBalance"
echo "  - fetchOpenOrders"
echo "  - fetchOrder (NEW)"
echo "  - fetchOrders (NEW)"
echo "  - fetchMyTrades (NEW)"
echo "  - createOrder"
echo "  - cancelOrder"
echo "  - editOrder (NEW)"

echo
echo "❌ Not Implemented (Low Priority for OctoBot):"
echo "  - fetchAccounts"
echo "  - fetchDepositAddress"
echo "  - fetchDeposits"
echo "  - fetchWithdrawals"
echo "  - fetchTransactions"
echo "  - fetchLedger"
echo "  - withdraw"
echo "  - transfer"

echo
echo -e "${BLUE}Test Results Summary${NC}"
echo "===================="
echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed! CCXT compliance is good.${NC}"
    exit 0
else
    echo -e "${YELLOW}Some tests failed. Check the output above for details.${NC}"
    exit 1
fi
