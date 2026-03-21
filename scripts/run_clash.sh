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

# =========================
# 参数解析
# =========================
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

if [ "$FOREGROUND" = true ] && [ "$DAEMON" = true ]; then
  echo "[ERROR] Cannot use both --foreground and --daemon" >&2
  exit 2
fi

if [ "$FOREGROUND" = false ] && [ "$DAEMON" = false ]; then
  echo "[ERROR] Must specify --foreground or --daemon" >&2
  exit 2
fi

# =========================
# 基础校验
# =========================
if [ ! -s "$CONFIG_FILE" ]; then
  echo "[ERROR] runtime config not found: $CONFIG_FILE" >&2
  exit 2
fi

if grep -q '\${' "$CONFIG_FILE"; then
  echo "[ERROR] unresolved placeholder found in $CONFIG_FILE" >&2
  exit 2
fi

# =========================
# 加载依赖
# =========================
# shellcheck disable=SC1091
source "$PROJECT_DIR/scripts/get_cpu_arch.sh"
# shellcheck disable=SC1091
source "$PROJECT_DIR/scripts/resolve_clash.sh"
# shellcheck disable=SC1091
source "$PROJECT_DIR/scripts/service_lib.sh"

# =========================
# 获取二进制
# =========================
CLASH_BIN="$(resolve_clash_bin "$PROJECT_DIR" "${CpuArch:-}")"

if [ ! -x "$CLASH_BIN" ]; then
  echo "[ERROR] clash binary not executable: $CLASH_BIN" >&2
  exit 2
fi

# =========================
# config 测试（唯一一次）
# =========================
if ! "$CLASH_BIN" -t -f "$CONFIG_FILE" -d "$RUNTIME_DIR" >/dev/null 2>&1; then
  echo "[ERROR] clash config test failed: $CONFIG_FILE" >&2
  write_run_state "failed" "config-test"
  exit 2
fi

# =========================
# 前台模式（systemd）
# =========================
if [ "$FOREGROUND" = true ]; then
  write_run_state "running" "systemd"
  exec "$CLASH_BIN" -f "$CONFIG_FILE" -d "$RUNTIME_DIR"
fi

# =========================
# 后台模式（script）
# =========================
cleanup_dead_pid

if is_script_running; then
  pid="$(read_pid 2>/dev/null || true)"
  echo "[INFO] clash already running, pid=${pid:-unknown}"
  exit 0
fi

nohup "$CLASH_BIN" -f "$CONFIG_FILE" -d "$RUNTIME_DIR" >>"$LOG_DIR/clash.log" 2>&1 &

pid=$!
echo "$pid" > "$PID_FILE"

write_run_state "running" "script" "$pid"

echo "[OK] Clash started in script mode, pid=$pid"