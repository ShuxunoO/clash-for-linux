#!/usr/bin/env bash
set -euo pipefail

Server_Dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
Service_Name="clash-for-linux.service"

log()   { printf "%b\n" "$*"; }
info()  { log "\033[36m[INFO]\033[0m $*"; }
ok()    { log "\033[32m[OK]\033[0m $*"; }
warn()  { log "\033[33m[WARN]\033[0m $*"; }
err()   { log "\033[31m[ERROR]\033[0m $*"; }

usage() {
  cat <<'EOF'
用法：
  bash restart.sh
  bash restart.sh --update
  bash restart.sh --no-systemd
EOF
}

USE_SYSTEMD="auto"
DO_UPDATE="false"

for arg in "$@"; do
  case "$arg" in
    --update)
      DO_UPDATE="true"
      ;;
    --no-systemd)
      USE_SYSTEMD="false"
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      err "未知参数: $arg"
      usage
      exit 1
      ;;
  esac
done

if [ "$DO_UPDATE" = "true" ]; then
  if [ -f "$Server_Dir/update.sh" ]; then
    info "执行更新脚本..."
    bash "$Server_Dir/update.sh"
  else
    err "未找到 update.sh: $Server_Dir/update.sh"
    exit 1
  fi
fi

has_systemd() {
  command -v systemctl >/dev/null 2>&1
}

service_exists() {
  systemctl list-unit-files 2>/dev/null | grep -q "^clash-for-linux.service"
}

restart_by_systemd() {
  info "使用 systemd 重启 Clash 服务..."
  systemctl restart "$Service_Name"
  systemctl --no-pager --full status "$Service_Name" || true

  if systemctl is-active --quiet "$Service_Name"; then
    ok "服务重启成功（systemd）"
  else
    err "服务重启失败（systemd）"
    exit 1
  fi
}

restart_by_scripts() {
  info "使用脚本方式重启 Clash..."

  if [ -f "$Server_Dir/shutdown.sh" ]; then
    bash "$Server_Dir/shutdown.sh" || true
  else
    warn "未找到 shutdown.sh，跳过关闭步骤"
  fi

  sleep 1

  if [ -f "$Server_Dir/start.sh" ]; then
    bash "$Server_Dir/start.sh"
  else
    err "未找到 start.sh: $Server_Dir/start.sh"
    exit 1
  fi

  ok "服务重启成功（script）"
}

if [ "$USE_SYSTEMD" = "auto" ]; then
  if has_systemd && service_exists; then
    USE_SYSTEMD="true"
  else
    USE_SYSTEMD="false"
  fi
fi

if [ "$USE_SYSTEMD" = "true" ]; then
  restart_by_systemd
else
  restart_by_scripts
fi