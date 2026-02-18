#!/bin/bash

################################################################################
# 模块: system
# 分类: core
# 描述: 系统更新和基础配置
# 依赖: 
# @category: core
# @description: 系统更新和基础配置
################################################################################

# 时区
TIMEZONE="${TIMEZONE:-Asia/Shanghai}"

# 基础依赖包
BASE_PACKAGES=(
    "curl"
    "wget"
    "git"
    "build-essential"
    "htop"
    "net-tools"
    "vim"
    "nano"
    "openssh-server"
)

# 检查函数
system_check() {
    # 总是执行
    return 0
}

# 执行函数
system_execute() {
    print_header "系统基础配置"

    if [[ "${INTERACTIVE_MODE:-false}" == "true" ]]; then
        print_info "本次将执行: 更新软件包列表、安装基础依赖、配置时区"
        print_info "时区: ${TIMEZONE:-Asia/Shanghai}"
    fi
    
    # 更新系统
    update_system
    
    # 安装依赖
    install_dependencies
    
    # 配置时区
    configure_timezone
    
    print_success "系统基础配置完成"
    return 0
}

# 更新系统
update_system() {
    print_status "更新系统软件包列表..."
    
    apt-get update -qq || {
        error_exit "更新软件包列表失败"
    }
    
    log "INFO" "系统软件包列表已更新"
    print_success "系统更新完成"
}

# 安装依赖
install_dependencies() {
    print_status "安装基础依赖..."
    
    local to_install=()
    
    for package in "${BASE_PACKAGES[@]}"; do
        if ! dpkg -l | grep -q "^ii  ${package} "; then
            to_install+=("$package")
        else
            log "DEBUG" "软件包已安装: $package"
        fi
    done
    
    if [[ ${#to_install[@]} -gt 0 ]]; then
        print_info "将要安装: ${to_install[*]}"
        apt-get install -y "${to_install[@]}" || {
            error_exit "安装依赖失败"
        }
        log "INFO" "已安装 ${#to_install[@]} 个软件包"
    else
        print_info "所有基础依赖已安装"
    fi
    
    print_success "依赖安装完成"
}

# 配置时区
configure_timezone() {
    print_status "配置时区为 ${TIMEZONE}..."
    
    if timedatectl set-timezone "$TIMEZONE" 2>/dev/null; then
        log "INFO" "时区已设置为: $TIMEZONE"
        print_success "时区配置完成"
    else
        print_warning "设置时区失败，使用系统默认"
    fi
}

# 注册模块
register_module \
    --name "system" \
    --category "core" \
    --description "系统更新和基础依赖安装"
