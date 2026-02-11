#!/bin/bash

################################################################################
# dpkg 修复工具
# 用于修复被中断的 dpkg 包管理器
################################################################################

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

################################################################################
# 修复函数
################################################################################

print_status() {
    echo -e "${BLUE}==>${NC} $*"
}

print_success() {
    echo -e "${GREEN}✓${NC} $*"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $*"
}

error_exit() {
    echo -e "${RED}✗${NC} $*" >&2
    exit 1
}

# 检查是否为 root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error_exit "此脚本必须以 root 身份运行"
    fi
}

# 修复 dpkg
fix_dpkg() {
    print_status "修复 dpkg 包管理器..."
    echo ""
    
    print_status "步骤 1: 清理损坏的 dpkg 状态..."
    
    # 清理损坏的状态文件
    if [[ -f /var/lib/dpkg/updates/0000 ]]; then
        rm -f /var/lib/dpkg/updates/*
        print_success "删除损坏的状态文件"
    fi
    
    # 配置所有未完成的包
    print_status "步骤 2: 配置未完成的包..."
    dpkg --configure -a 2>&1 || true
    print_success "配置完成"
    
    # 修复未满足的依赖
    print_status "步骤 3: 修复依赖关系..."
    apt-get install -f -y 2>&1 || true
    print_success "依赖修复完成"
    
    # 清理 apt 缓存
    print_status "步骤 4: 清理缓存..."
    apt-get clean
    apt-get autoclean
    apt-get autoremove -y 2>&1 || true
    print_success "缓存清理完成"
    
    # 更新包列表
    print_status "步骤 5: 更新包列表..."
    apt-get update
    print_success "包列表更新完成"
    
    echo ""
    print_success "dpkg 修复完成！"
}

# 验证 dpkg 状态
verify_dpkg() {
    print_status "验证 dpkg 状态..."
    
    # 检查 dpkg 是否正常
    if dpkg --configure -a 2>&1 | grep -q "Setting up"; then
        print_success "dpkg 状态正常"
        return 0
    fi
    
    # 尝试安装一个简单包来测试
    print_status "测试包管理器..."
    if apt-get install -y --simulate curl > /dev/null 2>&1; then
        print_success "包管理器工作正常"
        return 0
    fi
    
    return 1
}

################################################################################
# 主程序
################################################################################

main() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}  ${GREEN}dpkg 修复工具${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # 检查权限
    check_root
    
    # 显示警告
    print_warning "此脚本将修复 dpkg 包管理器"
    print_warning "操作过程中可能会自动删除或更新包"
    echo ""
    
    read -p "确定要继续吗? [y/N] " -n 1 -r confirm
    echo
    
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        echo "已取消"
        exit 0
    fi
    
    echo ""
    
    # 修复 dpkg
    fix_dpkg
    
    echo ""
    
    # 验证修复
    if verify_dpkg; then
        echo ""
        echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
        echo -e "${GREEN}修复成功！您可以继续运行初始化脚本${NC}"
        echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
        echo ""
        echo "下一步:"
        echo "  cd /root/vpc_init"
        echo "  sudo bash setup.sh"
        echo ""
    else
        error_exit "dpkg 修复失败，请检查系统状态"
    fi
}

# 运行主程序
main "$@"
