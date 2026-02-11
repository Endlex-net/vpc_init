#!/bin/bash

################################################################################
# 模块: firewall
# 分类: network
# 描述: 防火墙配置
# 依赖: system
# @category: network
# @description: 配置 UFW 防火墙
# @depends: system
################################################################################

# 防火墙端口
FIREWALL_PORTS=(22)

# 检查函数
firewall_check() {
    return 0
}

# 执行函数
firewall_execute() {
    print_header "防火墙配置"
    
    # 安装 UFW（如未安装）
    install_ufw
    
    # 配置规则
    configure_rules
    
    # 启用防火墙
    enable_firewall
    
    print_success "防火墙配置完成"
    return 0
}

# 安装 UFW
install_ufw() {
    if ! command -v ufw &>/dev/null; then
        print_status "安装 UFW 防火墙..."
        apt-get install -y ufw || {
            print_warning "安装 UFW 失败"
            return 1
        }
        log "INFO" "UFW 安装成功"
    fi
}

# 配置规则
configure_rules() {
    print_status "配置防火墙规则..."
    
    # 默认策略
    ufw default deny incoming
    ufw default allow outgoing
    
    # 允许 SSH
    ufw allow 22/tcp comment 'SSH'
    
    # 根据配置允许其他端口
    if [[ "${NGINX_ENABLE:-false}" == "true" ]]; then
        ufw allow 80/tcp comment 'HTTP'
        ufw allow 443/tcp comment 'HTTPS'
    fi
    
    log "INFO" "防火墙规则配置完成"
}

# 启用防火墙
enable_firewall() {
    print_status "启用防火墙..."
    
    if ufw status | grep -q "Status: active"; then
        print_info "防火墙已在运行"
    else
        echo "y" | ufw enable || {
            print_warning "启用防火墙失败"
            return 1
        }
        log "INFO" "防火墙已启用"
    fi
    
    # 显示状态
    print_info "防火墙状态:"
    ufw status numbered
}

# 注册模块
register_module \
    --name "firewall" \
    --category "network" \
    --description "配置 UFW 防火墙规则" \
    --depends-on "system"
