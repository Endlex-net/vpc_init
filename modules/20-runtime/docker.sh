#!/bin/bash

################################################################################
# 模块: docker
# 分类: runtime
# 描述: Docker 安装和配置
# 依赖: system
# @category: runtime
# @description: 安装 Docker 和 Docker Compose
# @depends: system
################################################################################

# 检查函数
docker_check() {
    if command -v docker &>/dev/null; then
        print_info "Docker 已安装"
        return 1
    fi
    return 0
}

# 执行函数
docker_execute() {
    print_header "Docker 安装"
    
    # 安装依赖
    install_prerequisites
    
    # 添加 Docker 仓库
    add_docker_repo
    
    # 安装 Docker
    install_docker_ce
    
    # 配置用户
    configure_user
    
    # 启动服务
    start_docker
    
    print_success "Docker 安装完成"
    return 0
}

# 安装前置依赖
install_prerequisites() {
    print_status "安装前置依赖..."
    apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
}

# 添加 Docker 仓库
add_docker_repo() {
    print_status "添加 Docker 官方仓库..."
    
    # 添加 GPG 密钥
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
        gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    # 添加仓库
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
        https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
        tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    apt-get update
}

# 安装 Docker CE
install_docker_ce() {
    print_status "安装 Docker CE..."
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
}

# 配置用户
configure_user() {
    if id "$USER_NAME" &>/dev/null; then
        usermod -aG docker "$USER_NAME"
        log "INFO" "用户 '$USER_NAME' 已添加到 docker 组"
    fi
}

# 启动 Docker
start_docker() {
    print_status "启动 Docker 服务..."
    systemctl enable docker
    systemctl start docker
    
    if docker --version &>/dev/null; then
        print_success "Docker 安装成功"
        docker --version
        docker compose version
    fi
}

# 注册模块
register_module \
    --name "docker" \
    --category "runtime" \
    --description "安装 Docker 和 Docker Compose" \
    --depends-on "system"
