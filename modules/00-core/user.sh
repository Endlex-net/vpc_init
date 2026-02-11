#!/bin/bash

################################################################################
# 模块: user
# 分类: core
# 描述: 用户创建和管理
# 依赖: 
# @category: core
# @description: 用户创建和管理
################################################################################

# 默认用户名
USER_NAME="${USER_NAME:-endlex}"
USER_PASSWORD=""

# 检查函数
user_check() {
    # 检查用户是否已存在
    if id "$USER_NAME" &>/dev/null; then
        print_info "用户 '$USER_NAME' 已存在"
        return 1  # 返回1表示不需要执行
    fi
    return 0
}

# 执行函数
user_execute() {
    print_header "用户管理"
    
    # 检查
    if ! user_check; then
        return 0
    fi
    
    # 生成密码
    USER_PASSWORD=$(generate_password)
    
    print_status "正在创建用户 '$USER_NAME'..."
    
    # 创建用户
    useradd -m -s /bin/bash -d "/home/${USER_NAME}" "${USER_NAME}" || {
        error_exit "创建用户失败"
    }
    
    # 设置密码
    echo "${USER_NAME}:${USER_PASSWORD}" | chpasswd || {
        error_exit "设置密码失败"
    }
    
    # 保存凭证
    local creds_file="/root/${USER_NAME}-credentials.txt"
    cat > "${creds_file}" << EOF
用户凭证 - ${USER_NAME}
===============================
创建时间: $(date)
用户名: ${USER_NAME}
密码: ${USER_PASSWORD}
主目录: /home/${USER_NAME}

重要提示: 请安全保存这些凭证信息。
此信息仅在用户创建时显示一次。
EOF
    
    chmod 600 "${creds_file}"
    
    log "INFO" "用户创建成功: ${USER_NAME}"
    print_success "用户 '$USER_NAME' 创建成功"
    print_info "凭证已保存到: ${creds_file}"
    
    return 0
}

# 配置函数（用于从配置文件读取）
user_configure() {
    # 从配置读取用户名
    if [[ -n "${CONFIG_USERNAME:-}" ]]; then
        USER_NAME="$CONFIG_USERNAME"
    fi
}

# 注册模块
register_module \
    --name "user" \
    --category "core" \
    --description "创建用户账户并生成安全密码"
