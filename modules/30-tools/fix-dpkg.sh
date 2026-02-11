#!/bin/bash

################################################################################
# 模块: fix-dpkg
# 分类: tools
# 描述: 修复 dpkg 错误
# @category: tools
# @description: 修复 dpkg 包管理器错误
################################################################################

fix_dpkg_execute() {
    print_header "修复 dpkg 错误"
    
    print_warning "此操作将修复常见的 dpkg 错误"
    
    if ! confirm "确认继续?" "Y"; then
        return 0
    fi
    
    # 步骤 1: 清理损坏的状态文件
    print_status "步骤 1/5: 清理损坏的状态文件..."
    rm -f /var/lib/dpkg/updates/*
    print_success "状态文件已清理"
    
    # 步骤 2: 配置未完成的包
    print_status "步骤 2/5: 配置未完成的包..."
    if dpkg --configure -a; then
        print_success "包配置完成"
    else
        print_warning "包配置可能有问题，继续..."
    fi
    
    # 步骤 3: 修复依赖关系
    print_status "步骤 3/5: 修复依赖关系..."
    apt-get install -f -y || true
    print_success "依赖修复完成"
    
    # 步骤 4: 清理缓存
    print_status "步骤 4/5: 清理 apt 缓存..."
    apt-get clean
    apt-get autoclean
    print_success "缓存已清理"
    
    # 步骤 5: 更新包列表
    print_status "步骤 5/5: 更新包列表..."
    apt-get update
    print_success "包列表已更新"
    
    # 验证修复
    echo ""
    print_status "验证修复结果..."
    if dpkg --audit &>/dev/null; then
        print_success "✓ dpkg 修复成功！"
        echo ""
        print_info "可以继续运行: sudo bash main.sh init"
        return 0
    else
        print_error "✗ dpkg 可能仍有问题"
        print_info "建议重启服务器后重试"
        return 1
    fi
}

register_module \
    --name "fix-dpkg" \
    --category "tools" \
    --description "修复 dpkg 包管理器错误"
