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

# 步骤1: 停止并禁用服务
echo "正在停止 sing-box 服务..."
if systemctl is-active --quiet sing-box.service; then
    systemctl stop sing-box.service
    echo "[OK] 服务已停止"
else
    echo "[INFO] 服务未运行"
fi

echo "正在禁用 sing-box 服务..."
if systemctl is-enabled --quiet sing-box.service 2>/dev/null; then
    systemctl disable sing-box.service
    echo "[OK] 服务已禁用"
else
    echo "[INFO] 服务未启用"
fi

# 步骤2: 删除配置文件
echo "正在删除配置文件..."
if [ -d "/etc/sing-box" ]; then
    rm -rf /etc/sing-box
    echo "[OK] 已删除 /etc/sing-box"
else
    echo "[INFO] 配置目录不存在"
fi

# 步骤3: 删除证书文件
echo "正在删除证书文件..."
if [ -f "/etc/ssl/private/bing.com.key" ]; then
    rm -f /etc/ssl/private/bing.com.key
    echo "[OK] 已删除 bing.com.key"
else
    echo "[INFO] 私钥文件不存在"
fi

if [ -f "/etc/ssl/private/bing.com.crt" ]; then
    rm -f /etc/ssl/private/bing.com.crt
    echo "[OK] 已删除 bing.com.crt"
else
    echo "[INFO] 证书文件不存在"
fi

# 检查 /etc/ssl/private 目录是否为空，如果为空则删除
if [ -d "/etc/ssl/private" ] && [ -z "$(ls -A /etc/ssl/private)" ]; then
    rmdir /etc/ssl/private
    echo "[OK] 已删除空目录 /etc/ssl/private"
fi

# 步骤4: 卸载 sing-box 程序
echo "正在卸载 sing-box 程序..."

# 查找 sing-box 可执行文件
SING_BOX_PATH=$(command -v sing-box 2>/dev/null || echo "")

if [ -n "$SING_BOX_PATH" ]; then
    rm -f "$SING_BOX_PATH"
    echo "[OK] 已删除 $SING_BOX_PATH"
else
    echo "[INFO] 未找到 sing-box 可执行文件"
fi

# 删除可能的 systemd 服务文件
if [ -f "/etc/systemd/system/sing-box.service" ]; then
    rm -f /etc/systemd/system/sing-box.service
    echo "[OK] 已删除服务文件"
fi

if [ -f "/usr/lib/systemd/system/sing-box.service" ]; then
    rm -f /usr/lib/systemd/system/sing-box.service
    echo "[OK] 已删除服务文件"
fi

# 重载 systemd
systemctl daemon-reload

# 步骤5: 清理可能的日志
echo "正在清理日志..."
if journalctl --unit=sing-box.service --quiet 2>/dev/null; then
    journalctl --rotate
    journalctl --vacuum-time=1s
    echo "[OK] 日志已清理"
fi

echo "========================================="
echo "[SUCCESS] sing-box 卸载完成!"
echo "========================================="
echo "已删除的内容:"
echo "  - sing-box 可执行文件"
echo "  - systemd 服务文件"
echo "  - 配置目录 /etc/sing-box"
echo "  - 证书文件 /etc/ssl/private/bing.com.*"
echo "  - 相关日志"
echo "========================================="
