#!/bin/bash

################################################################################
# 模块: security
# 分类: tools
# 描述: 安全加固
# 依赖: ssh
# @category: tools
# @description: 系统安全加固
# @depends: ssh
################################################################################

# 检查函数
security_check() {
    return 0
}

# 执行函数
security_execute() {
    print_header "安全加固"

    print_info "将执行以下加固项目:"
    echo "  • 禁用 root SSH 登录"
    echo "  • 禁用空密码登录"
    echo "  • 限制 SSH 认证尝试次数"
    echo "  • 禁用不必要的服务"
    echo "  • 配置系统限制"
    echo "  • 设置防火墙默认策略"

    # 交互确认已在执行计划阶段统一处理
    
    # SSH 安全加固
    harden_ssh
    
    # 系统安全设置
    harden_system
    
    # 防火墙加固
    harden_firewall
    
    print_success "安全加固完成"
    return 0
}

# SSH 加固
harden_ssh() {
    print_status "加固 SSH 配置..."
    
    local ssh_config="/etc/ssh/sshd_config"
    
    # 备份
    if [[ ! -f "${ssh_config}.backup" ]]; then
        cp "$ssh_config" "${ssh_config}.backup"
    fi
    
    # 禁用 root 登录
    sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' "$ssh_config"
    
    # 禁用空密码
    sed -i 's/^#*PermitEmptyPasswords.*/PermitEmptyPasswords no/' "$ssh_config"
    
    # 限制最大认证尝试
    if ! grep -q "^MaxAuthTries" "$ssh_config"; then
        echo "MaxAuthTries 3" >> "$ssh_config"
    fi
    
    # 重启 SSH
    systemctl restart sshd || systemctl restart ssh
    
    log "INFO" "SSH 加固完成"
}

# 系统加固
harden_system() {
    print_status "加固系统配置..."
    
    # 禁用不必要的服务
    local services=("bluetooth" "cups" "avahi-daemon")
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            systemctl stop "$service" 2>/dev/null || true
            systemctl disable "$service" 2>/dev/null || true
            log "INFO" "已禁用服务: $service"
        fi
    done
    
    # 配置系统限制
    cat >> /etc/security/limits.conf << 'EOF'

# 安全限制
* soft nofile 65535
* hard nofile 65535
* soft nproc 65535
* hard nproc 65535
EOF
    
    log "INFO" "系统加固完成"
}

# 防火墙加固
harden_firewall() {
    print_status "加固防火墙配置..."
    
    if command -v ufw &>/dev/null; then
        ufw default deny incoming
        ufw default allow outgoing
        log "INFO" "防火墙默认策略已设置"
    fi
}

# 注册模块
register_module \
    --name "security" \
    --category "tools" \
    --description "系统安全加固" \
    --depends-on "ssh"
