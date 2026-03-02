#!/bin/bash

# BitShares CCXT Bridge - Stop Script
# Simple script to stop the server for non-technical users

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
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

# Get port from .env file
if [ -f ".env" ]; then
    PORT=$(grep "^PORT=" .env | cut -d'=' -f2 | tr -d '"' | tr -d "'")
fi

if [ -z "$PORT" ]; then
    PORT=8787
fi

print_status "Stopping BitShares CCXT Bridge on port $PORT..."

# Find and kill processes using the port
PIDS=$(lsof -ti:$PORT 2>/dev/null || true)

if [ -z "$PIDS" ]; then
    print_warning "No server found running on port $PORT"
    exit 0
fi

# Kill the processes
for PID in $PIDS; do
    if kill -TERM "$PID" 2>/dev/null; then
        print_status "Stopped process $PID"
    else
        print_warning "Could not stop process $PID (may require sudo)"
    fi
done

# Wait a moment and check if processes are still running
sleep 2
REMAINING_PIDS=$(lsof -ti:$PORT 2>/dev/null || true)

if [ -n "$REMAINING_PIDS" ]; then
    print_warning "Some processes are still running. Force killing..."
    for PID in $REMAINING_PIDS; do
        kill -KILL "$PID" 2>/dev/null || true
    done
fi

print_status "✓ Server stopped successfully"
