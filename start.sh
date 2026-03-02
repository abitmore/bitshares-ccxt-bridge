#!/bin/bash

# BitShares CCXT Bridge - Start Script
# Simple script to start the server for non-technical users

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

# Check if .env file exists
if [ ! -f ".env" ]; then
    print_error "Configuration file (.env) not found!"
    echo "Please run ./install.sh first to set up the bridge."
    exit 1
fi

# Check if project is built
if [ ! -d "dist" ]; then
    print_warning "Project not built. Building now..."
    npm run build
fi

# Get port from .env file
PORT=$(grep "^PORT=" .env | cut -d'=' -f2 | tr -d '"' | tr -d "'")
if [ -z "$PORT" ]; then
    PORT=8787
fi

# Check if port is already in use
if lsof -Pi :$PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
    print_warning "Port $PORT is already in use."
    echo "Would you like to stop the existing process and restart? (y/n)"
    read -r restart
    if [[ "$restart" =~ ^[Yy]$ ]]; then
        ./stop.sh
        sleep 2
    else
        print_error "Cannot start server. Port $PORT is busy."
        exit 1
    fi
fi

print_status "Starting BitShares CCXT Bridge..."
print_status "Server will run on http://localhost:$PORT"
echo ""
echo "Available endpoints:"
echo "  • GET http://localhost:$PORT/markets"
echo "  • GET http://localhost:$PORT/ticker?symbol=BTS/USDT"
echo ""
echo "Press Ctrl+C to stop the server"
echo "Or run ./stop.sh from another terminal"
echo ""

# Start the server
npm start
