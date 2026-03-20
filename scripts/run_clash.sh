#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNTIME_DIR="$PROJECT_DIR/runtime"
LOG_DIR="$PROJECT_DIR/logs"
CONFIG_FILE="$RUNTIME_DIR/config.yaml"
PID_FILE="$RUNTIME_DIR/clash.pid"

mkdir -p "$RUNTIME_DIR" "$LOG_DIR"

FOREGROUND=false
DAEMON=false

for arg in "$@"; do
  case "$arg" in
    --foreground) FOREGROUND=true ;;
    --daemon) DAEMON=true ;;
    *)
      echo "[ERROR] Unknown arg: $arg" >&2
      exit 2
      ;;
  esac
done

if [ ! -s "$CONFIG_FILE" ]; then
  echo "[ERROR] runtime config not found: $CONFIG_FILE" >&2
  exit 2
fi

if grep -q '\${' "$CONFIG_FILE"; then
  echo "[ERROR] unresolved placeholder found in $CONFIG_FILE" >&2
  exit 2
fi

# 这里先沿用你原来的 resolve_clash.sh
# shellcheck disable=SC1091
source "$PROJECT_DIR/scripts/get_cpu_arch.sh"
# shellcheck disable=SC1091
source "$PROJECT_DIR/scripts/resolve_clash.sh"

CLASH_BIN="$(resolve_clash_bin "$PROJECT_DIR" "${CpuArch:-}")"

if [ "$FOREGROUND" = true ]; then
  exec "$CLASH_BIN" -f "$CONFIG_FILE" -d "$RUNTIME_DIR"
fi

if [ "$DAEMON" = true ]; then
  nohup "$CLASH_BIN" -f "$CONFIG_FILE" -d "$RUNTIME_DIR" >>"$LOG_DIR/clash.log" 2>&1 &
  echo $! > "$PID_FILE"
  echo "[OK] Clash started in script mode, pid=$(cat "$PID_FILE")"
  exit 0
fi

echo "[ERROR] Must specify --foreground or --daemon" >&2
exit 2