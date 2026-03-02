#!/bin/bash

# BitShares CCXT Bridge - Logs Script
# Simple script to view server logs for non-technical users

set -e

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
    echo -e "${BLUE}  BitShares CCXT Bridge Logs${NC}"
    echo -e "${BLUE}================================${NC}"
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
PIDS=$(lsof -ti:$PORT 2>/dev/null || true)

if [ -z "$PIDS" ]; then
    print_warning "Server is not currently running on port $PORT"
    echo ""
    echo "To start the server: ./start.sh"
    exit 0
fi

print_status "Server is running on port $PORT (PID: $PIDS)"
echo ""
echo "Recent server activity:"
echo "Press Ctrl+C to stop viewing logs"
echo ""

# Show logs using journalctl if available (systemd systems)
if command -v journalctl >/dev/null 2>&1; then
    journalctl -f --since "10 minutes ago" | grep -i "bitshares\|ccxt\|node" || true
else
    # Fallback: show process output if possible
    print_warning "Live logs not available. Showing process information:"
    ps aux | grep -E "(node|bitshares)" | grep -v grep || true
fi
