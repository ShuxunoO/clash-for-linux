#!/usr/bin/env bash
set -e

SERVICE="clash-for-linux.service"

echo "[INFO] Updating config..."

# 只负责生成配置，不启动内核
bash start.sh --only-generate

echo "[INFO] Restarting systemd service..."

systemctl restart "$SERVICE"

echo "[OK] Clash restarted via systemd"