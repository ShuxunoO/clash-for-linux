#!/usr/bin/env bash
set -euo pipefail

Server_Dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
Install_Dir="${CLASH_INSTALL_DIR:-/opt/clash-for-linux}"

Service_Name="clash-for-linux"
Service_User="root"
Service_Group="root"

# =========================
# 基础校验
# =========================
if [ "$(id -u)" -ne 0 ]; then
  echo "[ERROR] root required" >&2
  exit 1
fi

if [ ! -f "${Server_Dir}/.env" ]; then
  echo "[ERROR] .env not found in ${Server_Dir}" >&2
  exit 1
fi

# =========================
# 同步文件
# =========================
mkdir -p "$Install_Dir"

if [ "$Server_Dir" != "$Install_Dir" ]; then
  echo "[INFO] sync project to ${Install_Dir}"
  if command -v rsync >/dev/null 2>&1; then
    rsync -a --delete --exclude '.git' "$Server_Dir/" "$Install_Dir/"
  else
    cp -a "$Server_Dir/." "$Install_Dir/"
  fi
fi

chmod +x "$Install_Dir"/clashctl 2>/dev/null || true
chmod +x "$Install_Dir"/scripts/* 2>/dev/null || true
chmod +x "$Install_Dir"/bin/* 2>/dev/null || true

# =========================
# 目录初始化（新结构）
# =========================
mkdir -p \
  "$Install_Dir/runtime" \
  "$Install_Dir/logs" \
  "$Install_Dir/config/mixin.d"

# =========================
# 加载 env
# =========================
# shellcheck disable=SC1090
source "$Install_Dir/.env"

# shellcheck disable=SC1090
source "$Install_Dir/scripts/get_cpu_arch.sh"

# shellcheck disable=SC1090
source "$Install_Dir/scripts/resolve_clash.sh"

# =========================
# 内核检查
# =========================
if ! resolve_clash_bin "$Install_Dir" "${CpuArch:-}" >/dev/null 2>&1; then
  echo "[ERROR] clash core not ready" >&2
  exit 1
fi

# =========================
# 安装 clashctl
# =========================
install -m 0755 "$Install_Dir/clashctl" /usr/local/bin/clashctl

# =========================
# 安装 proxy helper
# =========================
cat >/etc/profile.d/clash-for-linux.sh <<EOF
proxy_on() {
  local port="\${1:-7890}"
  export http_proxy="http://127.0.0.1:\${port}"
  export https_proxy="\$http_proxy"
  export HTTP_PROXY="\$http_proxy"
  export HTTPS_PROXY="\$http_proxy"
  export no_proxy="127.0.0.1,localhost"
  export NO_PROXY="\$no_proxy"
  echo "[OK] Proxy enabled: \$http_proxy"
}

proxy_off() {
  unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY no_proxy NO_PROXY
  echo "[OK] Proxy disabled"
}
EOF

chmod 644 /etc/profile.d/clash-for-linux.sh

# =========================
# 安装 systemd
# =========================
Service_Enabled="unknown"
Service_Started="unknown"

if command -v systemctl >/dev/null 2>&1; then
  CLASH_SERVICE_USER="$Service_User" CLASH_SERVICE_GROUP="$Service_Group" \
    "$Install_Dir/scripts/install_systemd.sh" "$Install_Dir"

  if [ "${CLASH_ENABLE_SERVICE:-true}" = "true" ]; then
    systemctl enable "${Service_Name}.service" || true
  fi

  if [ "${CLASH_START_SERVICE:-true}" = "true" ]; then
    systemctl start "${Service_Name}.service" || true
  fi

  if systemctl is-enabled --quiet "${Service_Name}.service" 2>/dev/null; then
    Service_Enabled="enabled"
  else
    Service_Enabled="disabled"
  fi

  if systemctl is-active --quiet "${Service_Name}.service" 2>/dev/null; then
    Service_Started="active"
  else
    Service_Started="inactive"
  fi
else
  echo "[WARN] systemd not found, will use script mode"
fi

# =========================
# 输出（全部收敛到 clashctl）
# =========================
echo
echo "=== Install Complete ==="
echo "Install Dir : $Install_Dir"
echo "clashctl    : /usr/local/bin/clashctl"

echo
echo "Next:"
echo "  clashctl generate"
echo "  clashctl start"
echo "  clashctl doctor"

echo
echo "Commands:"
echo "  clashctl status"
echo "  clashctl logs"
echo "  clashctl restart"
echo "  clashctl stop"