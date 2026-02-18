#!/bin/bash

################################################################################
# 模块: verify
# 分类: tools
# 描述: 系统环境验证
# @category: tools
# @description: 验证系统环境和兼容性
################################################################################

verify_execute() {
    print_header "系统环境验证"

    print_info "本次将执行: 系统版本、权限、网络、磁盘、内存检查"
    
    local errors=0
    local warnings=0
    
    # 检查操作系统
    echo ""
    print_status "检查操作系统..."
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        if [[ "$ID" == "ubuntu" ]]; then
            print_success "操作系统: Ubuntu $VERSION_ID"
        else
            print_warning "操作系统: $NAME (非 Ubuntu)"
            warnings=$((warnings+1))
        fi
    else
        print_error "无法识别操作系统"
        errors=$((errors+1))
    fi
    
    # 检查权限
    echo ""
    print_status "检查权限..."
    if [[ $EUID -eq 0 ]]; then
        print_success "权限: root"
    else
        print_error "权限: 非 root (需要 root 权限)"
        errors=$((errors+1))
    fi
    
    # 检查网络
    echo ""
    print_status "检查网络连接..."
    if ping -c 1 -W 3 8.8.8.8 &>/dev/null; then
        print_success "网络连接: 正常"
    else
        print_warning "网络连接: 可能有问题"
        warnings=$((warnings+1))
    fi
    
    # 检查磁盘空间
    echo ""
    print_status "检查磁盘空间..."
    local available=$(df / | tail -1 | awk '{print $4}')
    if [[ $available -gt 500000 ]]; then  # 约 500MB
        print_success "磁盘空间: 充足 ($(($available/1024))MB)"
    else
        print_warning "磁盘空间: 不足 ($(($available/1024))MB)"
        warnings=$((warnings+1))
    fi
    
    # 检查内存
    echo ""
    print_status "检查内存..."
    local mem=$(free -m 2>/dev/null | grep Mem | awk '{print $2}' || echo "0")
    if [[ $mem -gt 512 ]]; then
        print_success "内存: ${mem}MB"
    else
        print_warning "内存: ${mem}MB (建议至少 1GB)"
        warnings=$((warnings+1))
    fi
    
    # 显示总结
    echo ""
    print_header "验证结果"
    
    if [[ $errors -eq 0 && $warnings -eq 0 ]]; then
        print_success "✓ 所有检查通过，系统环境正常"
        return 0
    elif [[ $errors -eq 0 ]]; then
        print_warning "⚠ 有 $warnings 个警告，但可以继续"
        return 0
    else
        print_error "✗ 有 $errors 个错误，请先修复"
        return 1
    fi
}

register_module \
    --name "verify" \
    --category "tools" \
    --description "验证系统环境和兼容性"
