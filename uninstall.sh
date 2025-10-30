#!/bin/bash

# Shadowsocks (libev & rust) + simple-obfs 一键卸载脚本
# 适用于 Debian / Ubuntu
# 使用方法: bash uninstall.sh

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 打印函数
print_info() { echo -e "${GREEN}[信息]${NC} $1"; }
print_warn() { echo -e "${YELLOW}[警告]${NC} $1"; }
print_error() { echo -e "${RED}[错误]${NC} $1"; }
print_success() { echo -e "${GREEN}[成功]${NC} $1"; }
print_step() { echo -e "${BLUE}[步骤]${NC} $1"; }

# 检查 root 权限
if [ "$(id -u)" -ne 0 ]; then
    print_error "此脚本必须以 root 身份运行"
    exit 1
fi

print_warn "=== Shadowsocks 卸载脚本 ==="
echo "开始卸载以下组件："
echo "  - shadowsocks-libev"
echo "  - shadowsocks-rust"
echo "  - simple-obfs"
echo "  - 相关配置文件和服务"
echo

# 步骤 1: 停止并禁用服务
print_step "步骤 1/5: 停止并禁用服务"

print_info "停止 shadowsocks-libev 服务..."
if systemctl is-active --quiet shadowsocks-libev 2>/dev/null; then
    systemctl stop shadowsocks-libev
    print_success "shadowsocks-libev 服务已停止"
else
    print_info "shadowsocks-libev 服务未运行"
fi

if systemctl is-enabled --quiet shadowsocks-libev 2>/dev/null; then
    systemctl disable shadowsocks-libev
    print_success "shadowsocks-libev 服务已禁用"
fi

print_info "停止 shadowsocks-rust 服务..."
if systemctl is-active --quiet shadowsocks-rust 2>/dev/null; then
    systemctl stop shadowsocks-rust
    print_success "shadowsocks-rust 服务已停止"
else
    print_info "shadowsocks-rust 服务未运行"
fi

if systemctl is-enabled --quiet shadowsocks-rust 2>/dev/null; then
    systemctl disable shadowsocks-rust
    print_success "shadowsocks-rust 服务已禁用"
fi

echo

# 步骤 2: 删除 systemd 服务文件
print_step "步骤 2/5: 删除 systemd 服务文件"

if [ -f /etc/systemd/system/shadowsocks-rust.service ]; then
    rm -f /etc/systemd/system/shadowsocks-rust.service
    print_success "已删除 shadowsocks-rust.service"
fi

if [ -f /etc/systemd/system/shadowsocks-libev.service ]; then
    rm -f /etc/systemd/system/shadowsocks-libev.service
    print_success "已删除 shadowsocks-libev.service"
fi

systemctl daemon-reload
print_success "systemd 配置已重新加载"

echo

# 步骤 3: 卸载软件包和删除二进制文件
print_step "步骤 3/5: 卸载软件和删除二进制文件"

# 卸载 shadowsocks-libev
print_info "卸载 shadowsocks-libev..."
if dpkg -l | grep -q shadowsocks-libev; then
    apt remove --purge -y shadowsocks-libev
    print_success "shadowsocks-libev 已卸载"
else
    print_info "shadowsocks-libev 未安装（跳过）"
fi

# 删除 shadowsocks-rust 二进制文件
print_info "删除 shadowsocks-rust 二进制文件..."
RUST_BINS=(
    /usr/bin/sslocal
    /usr/bin/ssserver
    /usr/bin/ssmanager
    /usr/bin/ssurl
    /usr/bin/ssservice
)

for bin in "${RUST_BINS[@]}"; do
    if [ -f "$bin" ]; then
        rm -f "$bin"
        print_success "已删除 $bin"
    fi
done

# 删除 simple-obfs 二进制文件
print_info "删除 simple-obfs 二进制文件..."
OBFS_BINS=(
    /usr/bin/obfs-server
    /usr/bin/obfs-local
)

for bin in "${OBFS_BINS[@]}"; do
    if [ -f "$bin" ]; then
        rm -f "$bin"
        print_success "已删除 $bin"
    fi
done

echo

# 步骤 4: 删除配置文件和目录
print_step "步骤 4/5: 删除配置文件和目录"

if [ -d /etc/shadowsocks-libev ]; then
    rm -rf /etc/shadowsocks-libev
    print_success "已删除 /etc/shadowsocks-libev"
fi

if [ -d /etc/shadowsocks-rust ]; then
    rm -rf /etc/shadowsocks-rust
    print_success "已删除 /etc/shadowsocks-rust"
fi

print_success "配置文件已删除"

echo

# 步骤 5: 清理临时文件
print_step "步骤 5/5: 清理临时文件"

TEMP_FILES=(
    /tmp/shadowsocks-rust.tar.xz
    /tmp/simple-obfs.tar.gz
)

for file in "${TEMP_FILES[@]}"; do
    if [ -f "$file" ]; then
        rm -f "$file"
        print_success "已删除 $file"
    fi
done

# 清理 APT 缓存
print_info "清理 APT 缓存..."
apt autoremove -y
apt autoclean
print_success "APT 缓存清理完成"

echo

# 卸载总结
print_success "=========================================="
print_success "卸载完成！"
print_success "=========================================="
echo

print_info "已卸载的组件："
echo "  ✓ shadowsocks-libev"
echo "  ✓ shadowsocks-rust"
echo "  ✓ simple-obfs"
echo "  ✓ systemd 服务文件"
echo "  ✓ 配置文件目录"
echo

# 检查是否还有残留
print_info "检查残留文件..."
RESIDUAL=false

if command -v ss-server >/dev/null 2>&1; then
    print_warn "发现残留: ss-server 命令仍然存在"
    RESIDUAL=true
fi

if command -v ssserver >/dev/null 2>&1; then
    print_warn "发现残留: ssserver 命令仍然存在"
    RESIDUAL=true
fi

if command -v obfs-server >/dev/null 2>&1; then
    print_warn "发现残留: obfs-server 命令仍然存在"
    RESIDUAL=true
fi

if [ "$RESIDUAL" = false ]; then
    print_success "未发现残留文件"
fi

echo
print_info "如需重新安装，请运行安装脚本"
print_success "=========================================="
