#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PORT="${PORT:-$(grep -E '^PORT=' "$ROOT_DIR/.env" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '"' | tr -d "'")}"
[ -z "$PORT" ] && PORT=8787

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
err() { echo -e "${RED}[ERROR]${NC} $1"; }

if lsof -Pi ":$PORT" -sTCP:LISTEN -t >/dev/null 2>&1; then
  info "Port $PORT already in use. Assuming bridge running and proceeding with tests."
else
  info "Starting bridge on port $PORT for tests..."
  (cd "$ROOT_DIR" && PORT="$PORT" ./control.sh start)
  trap 'cd "$ROOT_DIR" && ./control.sh stop' EXIT
fi

BASE_URL="http://localhost:$PORT"

check_endpoint() {
  local name="$1" path="$2"
  info "Testing $name ($BASE_URL$path)"
  if curl -sSf "$BASE_URL$path" >/dev/null; then
    echo "✅ $name OK"
  else
    echo "❌ $name FAILED"
    exit 1
  fi
}

info "Running REST smoke tests..."
check_endpoint "describe" "/describe"
check_endpoint "markets" "/markets"
check_endpoint "ticker" "/ticker?symbol=BTS/USDT"
check_endpoint "orderbook" "/orderbook?symbol=BTS/USDT"
check_endpoint "trades" "/trades?symbol=BTS/USDT"
check_endpoint "ohlcv" "/ohlcv?symbol=BTS/USDT"

info "Running CCXT simple check..."
PORT="$PORT" bash "$ROOT_DIR/test-ccxt-simple.sh"

info "Running API test script..."
PORT="$PORT" bash "$ROOT_DIR/test-api.sh"

info "Running pairs test script..."
PORT="$PORT" bash "$ROOT_DIR/test-pairs.sh"

info "All e2e checks completed."
