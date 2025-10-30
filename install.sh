#!/bin/bash

set -e

# 设置默认值（支持位置参数和环境变量）
SB_VERSION=${1:-${SB_VERSION:-1.11.15}}  # 优先使用 $1，然后是环境变量，最后是默认值
TR_PORT=${TR_PORT:-65031}
VL_PORT=${VL_PORT:-65032}
VL_SNI=${VL_SNI:-www.cityofrc.us}

echo "========================================="
echo "sing-box 安装脚本"
echo "========================================="
echo "sing-box 版本: $SB_VERSION"
echo "Trojan 端口: $TR_PORT"
echo "VLESS 端口: $VL_PORT"
echo "VLESS SNI: $VL_SNI"
echo "========================================="

# 检查是否为root用户
if [ "$EUID" -ne 0 ]; then 
    echo "[ERROR] 请使用 root 权限运行此脚本"
    exit 1
fi

# 步骤0: 检查必要的依赖命令
echo "正在检查系统依赖..."
missing_deps=()
for cmd in curl openssl systemctl; do
    if ! command -v $cmd &> /dev/null; then
        missing_deps+=($cmd)
    fi
done

if [ ${#missing_deps[@]} -ne 0 ]; then
    echo "[ERROR] 未找到以下必要命令: ${missing_deps[*]}"
    echo "请先安装缺失的依赖，例如:"
    echo "  Ubuntu/Debian: apt-get install curl openssl systemd"
    echo "  CentOS/RHEL: yum install curl openssl systemd"
    exit 1
fi
echo "[OK] 依赖检查通过"

# 步骤0.5: 检查端口是否被占用
echo "正在检查端口占用情况..."
occupied_ports=()

for port in $TR_PORT $VL_PORT; do
    # 尝试使用 ss 命令，如果不存在则使用 netstat
    if command -v ss &> /dev/null; then
        if ss -tuln | grep -q ":$port "; then
            occupied_ports+=($port)
        fi
    elif command -v netstat &> /dev/null; then
        if netstat -tuln | grep -q ":$port "; then
            occupied_ports+=($port)
        fi
    else
        echo "[WARNING] 无法检查端口占用（ss 和 netstat 命令均不可用）"
        break
    fi
done

if [ ${#occupied_ports[@]} -ne 0 ]; then
    echo "[WARNING] 以下端口已被占用: ${occupied_ports[*]}"
    echo "这可能导致 sing-box 启动失败"
    read -p "是否继续安装？(y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "安装已取消"
        exit 0
    fi
fi
echo "[OK] 端口检查通过"

# 步骤1: 安装 sing-box
echo "正在安装 sing-box ${SB_VERSION}..."
if ! curl -fsSL https://sing-box.app/install.sh | sh -s -- --version ${SB_VERSION}; then
    echo "[ERROR] sing-box 安装失败"
    echo "可能的原因:"
    echo "  1. 网络连接问题"
    echo "  2. 版本号不存在"
    echo "  3. 下载源访问受限"
    exit 1
fi
echo "[OK] sing-box 安装成功"

# 步骤2: 创建配置文件
echo "正在创建配置文件..."
if ! mkdir -p /etc/sing-box; then
    echo "[ERROR] 无法创建目录 /etc/sing-box"
    exit 1
fi

if ! cat > /etc/sing-box/config.json <<EOF
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
then
    echo "[ERROR] 配置文件创建失败"
    exit 1
fi

echo "[OK] 配置文件已创建: /etc/sing-box/config.json"

# 步骤3: 生成自签名证书
echo "正在生成自签名证书..."
if ! mkdir -p /etc/ssl/private; then
    echo "[ERROR] 无法创建证书目录"
    exit 1
fi

# 生成 ECC 私钥
if ! openssl ecparam -genkey -name prime256v1 -out /etc/ssl/private/bing.com.key; then
    echo "[ERROR] 生成私钥失败"
    exit 1
fi

# 生成自签名证书
if ! openssl req -new -x509 -key /etc/ssl/private/bing.com.key -out /etc/ssl/private/bing.com.crt -subj "/CN=bing.com" -days 36500; then
    echo "[ERROR] 生成证书失败"
    rm -f /etc/ssl/private/bing.com.key
    exit 1
fi

# 设置正确的权限
chmod 700 /etc/ssl/private
chmod 600 /etc/ssl/private/bing.com.key
chmod 644 /etc/ssl/private/bing.com.crt

echo "[OK] 证书已生成完成"

# 步骤4: 启用并启动服务
echo "正在启用并启动 sing-box 服务..."
if ! systemctl enable sing-box.service --now; then
    echo "[ERROR] 服务启动失败"
    echo "请检查配置文件和日志:"
    journalctl -u sing-box -n 50
    exit 1
fi

# 检查服务状态
sleep 2
if systemctl is-active --quiet sing-box.service; then
    echo "========================================="
    echo "[SUCCESS] sing-box 安装成功!"
    echo "========================================="
    echo "服务状态: $(systemctl is-active sing-box.service)"
    echo "Trojan 端口: $TR_PORT"
    echo "VLESS 端口: $VL_PORT"
    echo "VLESS SNI: $VL_SNI"
    echo "========================================="
    echo "常用命令:"
    echo "  查看日志: journalctl -u sing-box -f"
    echo "  查看状态: systemctl status sing-box"
    echo "  重启服务: systemctl restart sing-box"
    echo "  停止服务: systemctl stop sing-box"
    echo "========================================="
else
    echo "[ERROR] 服务启动失败，请检查日志:"
    journalctl -u sing-box -n 50
    exit 1
fi
