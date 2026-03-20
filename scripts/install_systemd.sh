#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVICE_NAME="clash-for-linux"
UNIT_PATH="/etc/systemd/system/${SERVICE_NAME}.service"

SERVICE_USER="${CLASH_SERVICE_USER:-root}"
SERVICE_GROUP="${CLASH_SERVICE_GROUP:-root}"

RUNTIME_DIR="$PROJECT_DIR/runtime"
LOG_DIR="$PROJECT_DIR/logs"
CONF_DIR="$PROJECT_DIR/conf"

if [ "$(id -u)" -ne 0 ]; then
  echo "[ERROR] root required to install systemd unit" >&2
  exit 1
fi

install -d -m 0755 "$RUNTIME_DIR" "$LOG_DIR" "$CONF_DIR"

cat >"$UNIT_PATH" <<EOF
[Unit]
Description=Clash for Linux (Mihomo)
Documentation=https://github.com/wnlen/clash-for-linux
After=network-online.target nss-lookup.target
Wants=network-online.target
StartLimitIntervalSec=0
StartLimitBurst=10

[Service]
Type=simple
User=${SERVICE_USER}
Group=${SERVICE_GROUP}
WorkingDirectory=${PROJECT_DIR}
Environment=HOME=/root

ExecStart=/bin/bash ${PROJECT_DIR}/scripts/run_clash.sh --foreground
ExecStop=/bin/bash ${PROJECT_DIR}/clashctl --from-systemd stop

Restart=always
RestartSec=5s

KillMode=mixed
TimeoutStartSec=120
TimeoutStopSec=30

StandardOutput=journal
StandardError=journal

UMask=0022
NoNewPrivileges=false

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable "${SERVICE_NAME}.service" >/dev/null 2>&1 || true

echo "[OK] systemd unit installed: ${UNIT_PATH}"
echo "start   : systemctl start ${SERVICE_NAME}.service"
echo "stop    : systemctl stop ${SERVICE_NAME}.service"
echo "restart : systemctl restart ${SERVICE_NAME}.service"
echo "status  : systemctl status ${SERVICE_NAME}.service -l --no-pager"