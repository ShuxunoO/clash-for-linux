#!/bin/bash
set -euo pipefail

#################### 基本变量 ####################

Server_Dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
Service_Name="clash-for-linux"

Service_User="root"
Service_Group="root"

Unit_Path="/etc/systemd/system/${Service_Name}.service"
Env_File="$Server_Dir/temp/clash-for-linux.sh"

#################### 权限检查 ####################

if [ "$(id -u)" -ne 0 ]; then
  echo -e "[31m[ERROR] 需要 root 权限来安装 systemd 单元[0m"
  exit 1
fi

#################### 目录初始化 ####################

install -d -m 0755   "$Server_Dir/conf"   "$Server_Dir/logs"   "$Server_Dir/temp"

# 预创建 env 文件，避免 systemd 因路径不存在报错
: > "$Env_File"
chmod 0644 "$Env_File"

#################### 生成 systemd Unit ####################

cat >"$Unit_Path" <<EOF
[Unit]
Description=Clash for Linux (Mihomo)
Documentation=https://github.com/wnlen/clash-for-linux
After=network-online.target nss-lookup.target
Wants=network-online.target
StartLimitIntervalSec=0
StartLimitBurst=10

[Service]
Type=simple
User=$Service_User
Group=$Service_Group
WorkingDirectory=$Server_Dir

# 启动环境
Environment=SYSTEMD_MODE=true
Environment=CLASH_ENV_FILE=$Env_File
Environment=HOME=/root

# 主进程必须由 start.sh 最后一跳 exec 成 mihomo/clash
ExecStart=/bin/bash $Server_Dir/start.sh
ExecStop=/bin/bash $Server_Dir/shutdown.sh
ExecReload=/bin/kill -HUP \$MAINPID

# 常驻策略：即使上层脚本正常退出，也要由 systemd 拉回
Restart=always
RestartSec=5s

# 停止与日志
KillMode=mixed
TimeoutStartSec=120
TimeoutStopSec=30
StandardOutput=journal
StandardError=journal

# 安全与文件权限
UMask=0022
NoNewPrivileges=false

[Install]
WantedBy=multi-user.target
EOF

#################### 刷新 systemd ####################

systemctl daemon-reload
systemctl enable "$Service_Name".service >/dev/null 2>&1 || true

echo -e "[32m[OK] 已生成 systemd 单元: ${Unit_Path}[0m"
echo -e "已启用开机自启，可执行以下命令启动服务："
echo -e "  systemctl restart ${Service_Name}.service"
echo -e "查看状态："
echo -e "  systemctl status ${Service_Name}.service -l --no-pager"
