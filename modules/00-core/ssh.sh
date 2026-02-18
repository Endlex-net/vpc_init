#!/bin/bash

################################################################################
# 模块: ssh
# 分类: core
# 描述: SSH 配置和密钥管理
# 依赖: user
# @category: core
# @description: SSH 配置和密钥管理
# @depends: user
################################################################################

# SSH 配置
SSH_KEYS="${SSH_KEYS:-}"
SSH_PORT="${SSH_PORT:-22}"

# 检查函数
ssh_check() {
    # 检查用户是否存在
    if ! id "$USER_NAME" &>/dev/null; then
        error_exit "SSH 配置失败: 用户 '$USER_NAME' 不存在"
    fi
    return 0
}

# 执行函数
ssh_execute() {
    print_header "SSH 配置"

    if [[ "${INTERACTIVE_MODE:-false}" == "true" ]]; then
        print_info "本次将执行: 创建 SSH 目录、写入公钥、设置权限"
        if [[ -n "${SSH_KEYS:-}" ]]; then
            print_info "SSH 公钥: 已设置"
        else
            print_warning "SSH 公钥: 未设置"
        fi
        if ! confirm "确认继续配置 SSH?" "Y"; then
            print_warning "已取消 SSH 配置"
            return 0
        fi
    fi
    
    local ssh_dir="/home/${USER_NAME}/.ssh"
    local auth_keys="${ssh_dir}/authorized_keys"
    
    print_status "配置 SSH 目录..."
    
    # 创建 SSH 目录
    if [[ ! -d "$ssh_dir" ]]; then
        mkdir -p "$ssh_dir"
        chown "${USER_NAME}:${USER_NAME}" "$ssh_dir"
        chmod 700 "$ssh_dir"
        log "INFO" "创建 SSH 目录: $ssh_dir"
    fi
    
    # 创建 authorized_keys
    if [[ ! -f "$auth_keys" ]]; then
        touch "$auth_keys"
        chown "${USER_NAME}:${USER_NAME}" "$auth_keys"
        chmod 600 "$auth_keys"
        log "INFO" "创建 authorized_keys: $auth_keys"
    fi
    
    # 添加 SSH 密钥
    if [[ -n "$SSH_KEYS" ]]; then
        add_ssh_keys
    fi
    
    print_success "SSH 配置完成"
    return 0
}

# 添加 SSH 密钥
add_ssh_keys() {
    local auth_keys="/home/${USER_NAME}/.ssh/authorized_keys"
    
    print_status "添加 SSH 密钥..."
    
    # 解析逗号分隔的密钥
    IFS=',' read -ra KEY_ARRAY <<< "$SSH_KEYS"
    
    for key_item in "${KEY_ARRAY[@]}"; do
        key_item=$(echo "$key_item" | xargs)  # 去除空格
        
        if [[ -z "$key_item" ]]; then
            continue
        fi
        
        # 判断是文件路径还是密钥字符串
        if [[ -f "$key_item" ]]; then
            # 从文件读取
            local key_content=$(cat "$key_item")
            add_ssh_key "$key_content"
        elif [[ "$key_item" =~ ^ssh- ]]; then
            # 直接是密钥字符串
            add_ssh_key "$key_item"
        else
            log "WARN" "未知的 SSH 密钥格式: $key_item"
        fi
    done
}

# 添加单个 SSH 密钥
add_ssh_key() {
    local key="$1"
    local auth_keys="/home/${USER_NAME}/.ssh/authorized_keys"
    
    # 检查是否已存在
    local key_parts=$(echo "$key" | awk '{print $1, $2}')
    if grep -q "$key_parts" "$auth_keys" 2>/dev/null; then
        log "INFO" "SSH 密钥已存在"
        return 0
    fi
    
    # 添加密钥
    echo "$key" >> "$auth_keys"
    log "INFO" "添加 SSH 密钥成功"
}

# 注册模块
register_module \
    --name "ssh" \
    --category "core" \
    --description "配置 SSH 目录和密钥" \
    --depends-on "user"
