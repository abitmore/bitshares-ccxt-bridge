#!/usr/bin/env bash
# BitShares CCXT Bridge control script
# Usage: ./control.sh [build|start|stop|restart|status|test [account] [--verbose]]

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PORT="${PORT:-8787}"
LOG_DIR="$ROOT_DIR/logs"
PID_FILE="$ROOT_DIR/.server.pid"
NODE_BIN="$(command -v node || true)"
NPM_BIN="$(command -v npm || true)"
PY_BIN="$(command -v python || command -v python3 || true)"

mkdir -p "$LOG_DIR"

msg() { printf '[control] %s\n' "$*"; }
err() { printf '[control][ERROR] %s\n' "$*" 1>&2; }

kill_port() {
  KILL_PORT_VERBOSE=1 PORT="$PORT" "$NODE_BIN" "$ROOT_DIR/scripts/kill-port.js" || true
}

start_server() {
  export PORT
  kill_port
  msg "Starting server on port $PORT ..."
  # Run in background and store PID
  if [[ -f "$PID_FILE" ]] && ps -p "$(cat "$PID_FILE" )" >/dev/null 2>&1; then
    msg "Server already running with PID $(cat "$PID_FILE"). Use restart if you want to reload."
    return 0
  fi
  # Build first
  "$NPM_BIN" run build
  # Start
  nohup "$NPM_BIN" start >"$LOG_DIR/server.log" 2>&1 &
  echo $! > "$PID_FILE"
  sleep 1
  msg "Started. PID=$(cat "$PID_FILE") | Logs: $LOG_DIR/server.log"
}

stop_server() {
  local killed=0
  if [[ -f "$PID_FILE" ]]; then
    local pid
    pid="$(cat "$PID_FILE")"
    if ps -p "$pid" >/dev/null 2>&1; then
      msg "Stopping PID $pid ..."
      kill "$pid" 2>/dev/null || true
      sleep 1
      if ps -p "$pid" >/dev/null 2>&1; then
        msg "Force killing PID $pid ..."
        kill -9 "$pid" 2>/dev/null || true
      fi
      killed=1
    fi
    rm -f "$PID_FILE"
  fi
  # Also free the port in case PID tracking missed it
  kill_port
  if [[ "$killed" -eq 1 ]]; then
    msg "Stopped."
  else
    msg "No tracked server process. Ensured port $PORT is free."
  fi
}

status_server() {
  msg "Checking status on port $PORT ..."
  # Try HTTP ping first
  if command -v curl >/dev/null 2>&1; then
    if curl -fsS "http://localhost:$PORT/describe" >/dev/null; then
      msg "Server responding on http://localhost:$PORT"
    else
      msg "No HTTP response on http://localhost:$PORT"
    fi
  fi
  # Show any owning process (Windows: netstat; Unix: lsof)
  if [[ "$OS" == "Windows_NT" ]]; then
    msg "netstat for :$PORT"
    netstat -ano | grep ":$PORT" || true
  else
    command -v lsof >/dev/null 2>&1 && lsof -i :"$PORT" -sTCP:LISTEN || true
  fi
  if [[ -f "$PID_FILE" ]]; then
    if ps -p "$(cat "$PID_FILE")" >/dev/null 2>&1; then
      msg "Tracked PID: $(cat "$PID_FILE")"
    else
      msg "Tracked PID file exists but process not running."
    fi
  fi
}

test_compliance() {
  local acct="${1:-}"
  shift || true
  local extra_args=("$@")
  export BITSHARES_CCXT_BRIDGE_URL="http://localhost:$PORT"
  msg "Running CCXT compliance test against $BITSHARES_CCXT_BRIDGE_URL ..."
  if [[ -n "$acct" ]]; then
    msg "Using public-balance account: $acct"
    "$PY_BIN" "$ROOT_DIR/test/ccxt_compliance.py" "$acct" "${extra_args[@]}"
  else
    "$PY_BIN" "$ROOT_DIR/test/ccxt_compliance.py" "${extra_args[@]}"
  fi
}

usage() {
  cat <<EOF
Usage: ./control.sh <command> [args]

Commands:
  build                 Build the TypeScript project
  start                 Kill port if needed and start the server in background
  stop                  Stop the tracked server process and free the port
  restart               Stop then start
  status                Show server/port status
  test [account] [--verbose]
                        Run CCXT compliance test (optionally with public balance account)

Environment:
  PORT                  Server port (default 8787)
EOF
}

cmd="${1:-}"
shift || true
case "$cmd" in
  build)
    "$NPM_BIN" run build
    ;;
  start)
    start_server
    ;;
  stop)
    stop_server
    ;;
  restart)
    stop_server
    start_server
    ;;
  status)
    status_server
    ;;
  test)
    test_compliance "$@"
    ;;
  *)
    usage
    ;;
esac
