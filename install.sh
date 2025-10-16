#!/bin/bash

set -e

# 设置默认值
TR_PORT=${TR_PORT:-65031}
VL_PORT=${VL_PORT:-65032}
VL_SNI=${VL_SNI:-www.cityofrc.us}

echo "========================================="
echo "sing-box 安装脚本"
echo "========================================="
echo "Trojan 端口: $TR_PORT"
echo "VLESS 端口: $VL_PORT"
echo "VLESS SNI: $VL_SNI"
echo "========================================="

# 检查是否为root用户
if [ "$EUID" -ne 0 ]; then 
    echo "请使用 root 权限运行此脚本"
    exit 1
fi

# 步骤1: 安装 sing-box 1.11.15
echo "正在安装 sing-box 1.11.15..."
curl -fsSL https://sing-box.app/install.sh | sh -s -- --version 1.11.15

# 步骤2: 创建配置文件
echo "正在创建配置文件..."
mkdir -p /etc/sing-box

cat > /etc/sing-box/config.json <<EOF
{
  "log": {
    "disabled": false,
    "level": "info",
    "timestamp": true
  },
  "inbounds": [
    {
      "type": "trojan",
      "tag": "trojan-in",
      "listen": "::",
      "listen_port": ${TR_PORT},
      "users": [
        {
          "password": "hBh1uKxMhYr6yTc40MDIcg=="
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "www.bing.com",
        "certificate_path": "/etc/ssl/private/bing.com.crt",
        "key_path": "/etc/ssl/private/bing.com.key"
      }
    },
    {
      "type": "vless",
      "tag": "real-in",
      "listen": "::",
      "listen_port": ${VL_PORT},
      "users": [
        {
          "uuid": "43a1f08a-d9ff-4aea-ac8a-cc622caf62a5",
          "flow": "xtls-rprx-vision"
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "${VL_SNI}",
        "reality": {
          "enabled": true,
          "handshake": {
            "server": "${VL_SNI}",
            "server_port": 443
          },
          "private_key": "IJ7MvrtAgMGCJdLk4JHtaRci5uAIa2SD5aNO0hsNJ2U",
          "short_id": [
            "4eae9cfd38fb5a8d"
          ]
        }
      }
    }
  ],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    }
  ]
}
EOF

echo "配置文件已创建: /etc/sing-box/config.json"

# 步骤3: 生成自签名证书
echo "正在生成自签名证书..."
mkdir -p /etc/ssl/private
openssl req -x509 -nodes -newkey ec:<(openssl ecparam -name prime256v1) -keyout /etc/ssl/private/bing.com.key -out /etc/ssl/private/bing.com.crt -subj "/CN=bing.com" -days 36500 && chmod -R 777 /etc/ssl/private

echo "证书已生成完成"

# 步骤4: 启用并启动服务
echo "正在启用并启动 sing-box 服务..."
systemctl enable sing-box.service --now

# 检查服务状态
sleep 2
if systemctl is-active --quiet sing-box.service; then
    echo "========================================="
    echo "✓ sing-box 安装成功!"
    echo "========================================="
    echo "服务状态: $(systemctl is-active sing-box.service)"
    echo "Trojan 端口: $TR_PORT"
    echo "VLESS 端口: $VL_PORT"
    echo "VLESS SNI: $VL_SNI"
    echo "========================================="
    echo "查看日志: journalctl -u sing-box -f"
    echo "查看状态: systemctl status sing-box"
else
    echo "❌ 服务启动失败，请检查日志:"
    journalctl -u sing-box -n 50
    exit 1
fi
