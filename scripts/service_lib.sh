#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNTIME_DIR="$PROJECT_DIR/runtime"
PID_FILE="$RUNTIME_DIR/clash.pid"
SERVICE_NAME="clash-for-linux.service"

mkdir -p "$RUNTIME_DIR"

has_systemd() {
  command -v systemctl >/dev/null 2>&1
}

service_unit_exists() {
  has_systemd || return 1
  systemctl show "$SERVICE_NAME" -p LoadState --value 2>/dev/null | grep -q '^loaded$'
}

detect_mode() {
  if service_unit_exists && systemctl is-active --quiet "$SERVICE_NAME"; then
    echo "systemd"
  elif is_script_running; then
    echo "script"
  elif service_unit_exists; then
    echo "systemd-installed"
  else
    echo "none"
  fi
}

read_pid() {
  [ -f "$PID_FILE" ] || return 1
  cat "$PID_FILE"
}

is_script_running() {
  local pid
  pid="$(read_pid 2>/dev/null || true)"
  [ -n "${pid:-}" ] && kill -0 "$pid" 2>/dev/null
}

start_via_systemd() {
  systemctl start "$SERVICE_NAME"
}

stop_via_systemd() {
  systemctl stop "$SERVICE_NAME"
}

restart_via_systemd() {
  systemctl restart "$SERVICE_NAME"
}

start_via_script() {
  if is_script_running; then
    echo "[INFO] clash already running (script mode)"
    return 0
  fi
  "$PROJECT_DIR/scripts/run_clash.sh" --daemon
}

stop_via_script() {
  local pid
  pid="$(read_pid 2>/dev/null || true)"
  if [ -n "${pid:-}" ] && kill -0 "$pid" 2>/dev/null; then
    echo "[INFO] stopping clash pid=$pid"
    kill "$pid"
    sleep 1
    if kill -0 "$pid" 2>/dev/null; then
      kill -9 "$pid" 2>/dev/null || true
    fi
  fi
  rm -f "$PID_FILE"
}

restart_via_script() {
  stop_via_script || true
  start_via_script
}