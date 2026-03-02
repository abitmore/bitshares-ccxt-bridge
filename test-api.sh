#!/bin/bash

# BitShares CCXT Bridge - API Test Script
# Simple script to test the API endpoints for non-technical users

set -e

# Ensure clean output
exec 2>/dev/null

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}  BitShares CCXT Bridge Test${NC}"
    echo -e "${BLUE}================================${NC}"
    echo ""
}

# Function to test API endpoint
test_endpoint() {
    local url="$1"
    local description="$2"
    
    echo "Testing: $description"
    echo "URL: $url"
    echo ""
    
    if curl -s --max-time 10 "$url" > /tmp/api_response.json 2>/dev/null; then
        if [ -s /tmp/api_response.json ]; then
            # Check if response contains error
            if grep -q '"error"' /tmp/api_response.json 2>/dev/null; then
                print_warning "⚠ API Error:"
                cat /tmp/api_response.json | jq . 2>/dev/null || cat /tmp/api_response.json
            else
                print_status "✓ Success!"
                echo "Response preview:"
                head -c 300 /tmp/api_response.json | jq . 2>/dev/null || head -c 300 /tmp/api_response.json
                if [ $(wc -c < /tmp/api_response.json) -gt 300 ]; then
                    echo "... (response truncated)"
                fi
            fi
        else
            print_warning "⚠ Empty response"
        fi
    else
        print_error "✗ Failed to connect"
    fi
    echo ""
    echo "----------------------------------------"
    echo ""
}

# Get port from .env file
if [ -f ".env" ]; then
    PORT=$(grep "^PORT=" .env | cut -d'=' -f2 | tr -d '"' | tr -d "'")
fi

if [ -z "$PORT" ]; then
    PORT=8787
fi

BASE_URL="http://localhost:$PORT"

print_header

# Check if server is running
if ! curl -s --max-time 5 "$BASE_URL" >/dev/null 2>&1; then
    print_error "Server is not running on port $PORT"
    echo ""
    echo "To start the server: ./start.sh"
    exit 1
fi

print_status "Server is running on $BASE_URL"
echo ""

# Test endpoints
test_endpoint "$BASE_URL/markets" "Get all available markets"

# Test your specific BitShares pairs
test_endpoint "$BASE_URL/ticker?symbol=XBTSX.NCH/XBTSX.NESS" "Get XBTSX.NCH/XBTSX.NESS ticker"
test_endpoint "$BASE_URL/ticker?symbol=SCH/NESS" "Get SCH/NESS ticker"
test_endpoint "$BASE_URL/ticker?symbol=NCH/BTS" "Get NCH/BTS ticker"
test_endpoint "$BASE_URL/ticker?symbol=NESS/BTS" "Get NESS/BTS ticker"
test_endpoint "$BASE_URL/ticker?symbol=NESS/DOGE" "Get NESS/DOGE ticker"
test_endpoint "$BASE_URL/ticker?symbol=NESS/USDC" "Get NESS/USDC ticker"

# Test some common pairs for reference
test_endpoint "$BASE_URL/ticker?symbol=BTS/USDT" "Get BTS/USDT ticker (reference)"

# Clean up
rm -f /tmp/api_response.json

print_status "API testing complete!"
echo ""
echo "If you see errors above, check:"
echo "  • Server logs: ./logs.sh"
echo "  • Configuration: cat .env"
echo "  • Restart server: ./stop.sh && ./start.sh"
