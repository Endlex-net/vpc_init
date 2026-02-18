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

    if [[ "${INTERACTIVE_MODE:-false}" == "true" ]]; then
        print_info "本次将执行: 安装 UFW、设置默认策略、开放必要端口"
    fi
    
    # 安装 UFW（如未安装）
    install_ufw
    
    # 配置规则
    configure_rules

    # 交互式端口管理
    if [[ "${INTERACTIVE_MODE:-false}" == "true" ]]; then
        manage_ports_interactive
    fi
    
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

# 交互式端口管理
manage_ports_interactive() {
    while true; do
        echo ""
        print_info "端口管理"
        echo "  1) 添加端口"
        echo "  2) 删除端口"
        echo "  3) 查看当前规则"
        echo "  0) 返回"
        echo ""

        read -p "请选择: " -r choice
        case "$choice" in
            1)
                prompt_add_ports
                ;;
            2)
                prompt_remove_ports
                ;;
            3)
                ufw status numbered
                ;;
            0)
                return 0
                ;;
            *)
                print_warning "无效选项"
                ;;
        esac
    done
}

# 添加端口
prompt_add_ports() {
    read -p "请输入要添加的端口(支持 80 或 80/tcp, 多个用逗号分隔): " -r ports
    if [[ -z "$ports" ]]; then
        print_warning "未输入端口"
        return 0
    fi

    IFS=',' read -ra PORT_LIST <<< "$ports"
    for port in "${PORT_LIST[@]}"; do
        port=$(echo "$port" | xargs)
        if ! validate_port "$port"; then
            print_warning "端口格式无效: $port"
            continue
        fi
        ufw allow "$port" || print_warning "添加端口失败: $port"
    done
}

# 删除端口
prompt_remove_ports() {
    read -p "请输入要删除的端口(支持 80 或 80/tcp, 多个用逗号分隔): " -r ports
    if [[ -z "$ports" ]]; then
        print_warning "未输入端口"
        return 0
    fi

    IFS=',' read -ra PORT_LIST <<< "$ports"
    for port in "${PORT_LIST[@]}"; do
        port=$(echo "$port" | xargs)
        if ! validate_port "$port"; then
            print_warning "端口格式无效: $port"
            continue
        fi
        ufw delete allow "$port" || print_warning "删除端口失败: $port"
    done
}

# 端口格式校验
validate_port() {
    local port="$1"
    if [[ "$port" =~ ^[0-9]+$ ]]; then
        [[ "$port" -ge 1 && "$port" -le 65535 ]]
        return $?
    fi
    if [[ "$port" =~ ^[0-9]+/(tcp|udp)$ ]]; then
        local num=${port%%/*}
        [[ "$num" -ge 1 && "$num" -le 65535 ]]
        return $?
    fi
    return 1
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
