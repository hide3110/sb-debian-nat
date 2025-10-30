#!/bin/bash

set -e

echo "========================================="
echo "sing-box 卸载脚本"
echo "========================================="

# 检查是否为root用户
if [ "$EUID" -ne 0 ]; then 
    echo "[ERROR] 请使用 root 权限运行此脚本"
    exit 1
fi

# 步骤1: 停止服务
echo "正在停止 sing-box 服务..."
if systemctl is-active --quiet sing-box.service; then
    if systemctl stop sing-box.service; then
        echo "[OK] 服务已停止"
    else
        echo "[WARNING] 停止服务失败，继续卸载..."
    fi
else
    echo "[OK] 服务未运行"
fi

# 步骤2: 禁用服务
echo "正在禁用 sing-box 服务..."
if systemctl is-enabled --quiet sing-box.service 2>/dev/null; then
    if systemctl disable sing-box.service; then
        echo "[OK] 服务已禁用"
    else
        echo "[WARNING] 禁用服务失败，继续卸载..."
    fi
else
    echo "[OK] 服务未启用"
fi

# 步骤3: 删除配置文件
echo "正在删除配置文件..."
if [ -d "/etc/sing-box" ]; then
    if rm -rf /etc/sing-box; then
        echo "[OK] 配置文件已删除"
    else
        echo "[ERROR] 删除配置文件失败"
    fi
else
    echo "[OK] 配置目录不存在"
fi

# 步骤4: 删除证书文件
echo "正在删除证书文件..."
cert_files_deleted=0
if [ -f "/etc/ssl/private/bing.com.key" ]; then
    rm -f /etc/ssl/private/bing.com.key
    cert_files_deleted=$((cert_files_deleted + 1))
fi
if [ -f "/etc/ssl/private/bing.com.crt" ]; then
    rm -f /etc/ssl/private/bing.com.crt
    cert_files_deleted=$((cert_files_deleted + 1))
fi

if [ $cert_files_deleted -gt 0 ]; then
    echo "[OK] 证书文件已删除 ($cert_files_deleted 个文件)"
else
    echo "[OK] 证书文件不存在"
fi

# 步骤5: 删除 systemd 服务文件
echo "正在删除 systemd 服务文件..."
service_files=(
    "/etc/systemd/system/sing-box.service"
    "/usr/lib/systemd/system/sing-box.service"
    "/lib/systemd/system/sing-box.service"
)

service_deleted=0
for service_file in "${service_files[@]}"; do
    if [ -f "$service_file" ]; then
        if rm -f "$service_file"; then
            service_deleted=$((service_deleted + 1))
        fi
    fi
done

if [ $service_deleted -gt 0 ]; then
    systemctl daemon-reload
    echo "[OK] systemd 服务文件已删除"
else
    echo "[OK] systemd 服务文件不存在"
fi

# 步骤6: 删除 sing-box 二进制文件
echo "正在删除 sing-box 程序..."
binary_files=(
    "/usr/local/bin/sing-box"
    "/usr/bin/sing-box"
)

binary_deleted=0
for binary_file in "${binary_files[@]}"; do
    if [ -f "$binary_file" ]; then
        if rm -f "$binary_file"; then
            echo "[OK] 已删除: $binary_file"
            binary_deleted=$((binary_deleted + 1))
        fi
    fi
done

if [ $binary_deleted -eq 0 ]; then
    echo "[OK] sing-box 程序不存在"
fi

# 步骤7: 清理日志
echo "正在清理日志..."
if journalctl --rotate &>/dev/null && journalctl --vacuum-time=1s -u sing-box &>/dev/null; then
    echo "[OK] 日志已清理"
else
    echo "[WARNING] 日志清理失败或无权限"
fi

# 步骤8: 检查残留文件
echo "正在检查残留文件..."
残留=0
if [ -d "/var/lib/sing-box" ]; then
    echo "[WARNING] 发现数据目录: /var/lib/sing-box"
    if rm -rf /var/lib/sing-box; then
        echo "[OK] 数据目录已删除"
    else
        echo "[ERROR] 删除数据目录失败"
    fi
fi

# 最终检查
echo "========================================="
echo "正在进行最终检查..."

# 检查服务是否还存在
if systemctl list-unit-files | grep -q sing-box; then
    echo "[WARNING] systemd 中仍存在 sing-box 服务"
    残留=1
fi

# 检查二进制文件
if command -v sing-box &> /dev/null; then
    echo "[WARNING] sing-box 命令仍然可用: $(which sing-box)"
    残留=1
fi

# 检查配置目录
if [ -d "/etc/sing-box" ]; then
    echo "[WARNING] 配置目录仍然存在: /etc/sing-box"
    残留=1
fi

echo "========================================="
if [ $残留 -eq 0 ]; then
    echo "[SUCCESS] sing-box 已完全卸载!"
else
    echo "[WARNING] 卸载完成，但检测到部分残留文件"
    echo "您可以手动检查并清理这些文件"
fi
echo "========================================="
