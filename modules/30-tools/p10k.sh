#!/bin/bash

################################################################################
# 模块: p10k
# 分类: tools
# 描述: Powerlevel10k 安装
# 依赖: user
# @category: tools
# @description: 安装 Powerlevel10k (zsh 主题)
# @depends: user
################################################################################

# 检查函数
p10k_check() {
    if [[ -d "/home/${USER_NAME}/.oh-my-zsh/custom/themes/powerlevel10k" ]]; then
        print_info "Powerlevel10k 已安装"
        return 1
    fi
    return 0
}

# 执行函数
p10k_execute() {
    print_header "Powerlevel10k 安装"

    if [[ "${INTERACTIVE_MODE:-false}" == "true" ]]; then
        print_info "将安装 zsh、Oh My Zsh 和 Powerlevel10k"
        if ! confirm "确认继续安装?" "Y"; then
            print_warning "已取消安装"
            return 0
        fi
    fi
    
    # 检查用户
    if ! id "$USER_NAME" &>/dev/null; then
        error_exit "用户 '$USER_NAME' 不存在"
    fi
    
    # 安装 zsh
    install_zsh
    
    # 安装 Oh My Zsh
    install_ohmyzsh
    
    # 安装 Powerlevel10k
    install_p10k_theme
    
    # 配置主题
    configure_theme
    
    print_success "Powerlevel10k 安装完成"
    return 0
}

# 安装 zsh
install_zsh() {
    if command -v zsh &>/dev/null; then
        return 0
    fi
    
    print_status "安装 Zsh..."
    apt-get install -y zsh
}

# 安装 Oh My Zsh
install_ohmyzsh() {
    if [[ -d "/home/${USER_NAME}/.oh-my-zsh" ]]; then
        return 0
    fi
    
    print_status "安装 Oh My Zsh..."
    
    sudo -u "$USER_NAME" bash -c '
        export RUNZSH=no
        export CHSH=no
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    '
}

# 安装 Powerlevel10k 主题
install_p10k_theme() {
    print_status "安装 Powerlevel10k..."
    
    local p10k_dir="/home/${USER_NAME}/.oh-my-zsh/custom/themes/powerlevel10k"
    
    if [[ ! -d "$p10k_dir" ]]; then
        git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$p10k_dir"
        chown -R "$USER_NAME:$USER_NAME" "$p10k_dir"
    fi
}

# 配置主题
configure_theme() {
    print_status "配置 Zsh 主题..."
    
    local zshrc="/home/${USER_NAME}/.zshrc"
    
    # 设置主题
    sed -i 's/ZSH_THEME=.*/ZSH_THEME="powerlevel10k\/powerlevel10k"/' "$zshrc"
    
    # 更改默认 shell
    chsh -s /usr/bin/zsh "$USER_NAME"
    
    log "INFO" "Powerlevel10k 配置完成"
}

# 注册模块
register_module \
    --name "p10k" \
    --category "tools" \
    --description "安装 Powerlevel10k (zsh 主题)" \
    --depends-on "user"
