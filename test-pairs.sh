#!/bin/bash

# BitShares CCXT Bridge - Test Your Specific Pairs
# Clean test script for your XBTSX pairs

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
    echo -e "${BLUE}  Testing Your BitShares Pairs${NC}"
    echo -e "${BLUE}================================${NC}"
    echo ""
}

# Function to test a single pair
test_pair() {
    local symbol="$1"
    echo "Testing: $symbol"
    
    local response=$(curl -s --max-time 10 "http://localhost:8787/ticker?symbol=$symbol" 2>/dev/null)
    
    if [ -n "$response" ]; then
        if echo "$response" | grep -q '"error"'; then
            print_error "✗ Error: $(echo "$response" | grep -o '"error":"[^"]*"' | cut -d'"' -f4)"
        else
            local last=$(echo "$response" | grep -o '"last":[0-9.]*' | cut -d':' -f2)
            local bid=$(echo "$response" | grep -o '"bid":[0-9.]*' | cut -d':' -f2)
            local ask=$(echo "$response" | grep -o '"ask":[0-9.]*' | cut -d':' -f2)
            print_status "✓ Last: $last | Bid: $bid | Ask: $ask"
        fi
    else
        print_error "✗ No response"
    fi
    echo ""
}

# Get port from .env file
if [ -f ".env" ]; then
    PORT=$(grep "^PORT=" .env | cut -d'=' -f2 | tr -d '"' | tr -d "'")
fi

if [ -z "$PORT" ]; then
    PORT=8787
fi

print_header

# Check if server is running
if ! curl -s --max-time 5 "http://localhost:$PORT/markets" >/dev/null 2>&1; then
    print_error "Server is not running on port $PORT"
    echo "Start it with: ./start.sh"
    exit 1
fi

print_status "Server is running on http://localhost:$PORT"
echo ""

# Test your specific pairs (using actual available pairs)
echo "Testing your BitShares pairs:"
echo ""

test_pair "BTS/NESS"
test_pair "BTS/SCH" 
test_pair "BTS/NCH"
test_pair "BTC/NESS"
test_pair "BTC/SCH"
test_pair "BTC/NCH"
test_pair "ETH/NESS"
test_pair "ETH/SCH"
test_pair "STH/NESS"
test_pair "STH/SCH"

echo "Reference pairs:"
echo ""
test_pair "BTS/USDT"

print_status "Pair testing complete!"
