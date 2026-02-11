#!/bin/bash

################################################################################
# 模块: nginx
# 分类: network
# 描述: Nginx 安装和配置
# 依赖: firewall
# @category: network
# @description: 安装并配置 Nginx（支持 SSL 和反向代理）
# @depends: firewall
################################################################################

# Nginx 配置
NGINX_DOMAIN="${NGINX_DOMAIN:-}"
NGINX_ENABLE_SSL="${NGINX_ENABLE_SSL:-false}"
NGINX_BACKEND="${NGINX_BACKEND:-}"

# 检查函数
nginx_check() {
    # 如果没有配置域名，询问用户
    if [[ -z "$NGINX_DOMAIN" ]]; then
        print_info "未配置 Nginx 域名，跳过"
        return 1
    fi
    return 0
}

# 执行函数
nginx_execute() {
    print_header "Nginx 安装和配置"
    
    # 安装 Nginx
    install_nginx
    
    # 配置站点
    configure_site
    
    # 配置 SSL（如启用）
    if [[ "$NGINX_ENABLE_SSL" == "true" ]]; then
        setup_ssl
    fi
    
    # 启动 Nginx
    start_nginx
    
    print_success "Nginx 配置完成"
    return 0
}

# 安装 Nginx
install_nginx() {
    if command -v nginx &>/dev/null; then
        print_info "Nginx 已安装"
        return 0
    fi
    
    print_status "安装 Nginx..."
    apt-get install -y nginx || {
        error_exit "安装 Nginx 失败"
    }
    
    log "INFO" "Nginx 安装成功"
    print_success "Nginx 安装完成"
}

# 配置站点
configure_site() {
    print_status "配置 Nginx 站点: $NGINX_DOMAIN"
    
    local site_root="/var/www/${NGINX_DOMAIN}"
    local config_file="/etc/nginx/sites-available/${NGINX_DOMAIN}"
    
    # 创建站点目录
    mkdir -p "$site_root"
    chown -R www-data:www-data "$site_root"
    
    # 创建默认页面
    create_default_page "$site_root"
    
    # 生成配置
    if [[ -n "$NGINX_BACKEND" ]]; then
        # 反向代理配置
        create_proxy_config "$config_file" "$site_root"
    else
        # 静态站点配置
        create_static_config "$config_file" "$site_root"
    fi
    
    # 启用站点
    if [[ ! -L "/etc/nginx/sites-enabled/${NGINX_DOMAIN}" ]]; then
        ln -s "$config_file" "/etc/nginx/sites-enabled/${NGINX_DOMAIN}"
    fi
    
    # 测试配置
    if nginx -t; then
        print_success "Nginx 配置测试通过"
    else
        error_exit "Nginx 配置测试失败"
    fi
    
    log "INFO" "站点配置完成: $NGINX_DOMAIN"
}

# 创建默认页面
create_default_page() {
    local root="$1"
    cat > "${root}/index.html" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Welcome to ${NGINX_DOMAIN}</title>
    <style>
        body { font-family: Arial, sans-serif; text-align: center; padding: 50px; }
        h1 { color: #333; }
    </style>
</head>
<body>
    <h1>Welcome to ${NGINX_DOMAIN}!</h1>
    <p>Nginx is successfully installed and configured.</p>
</body>
</html>
EOF
}

# 创建静态站点配置
create_static_config() {
    local config_file="$1"
    local root="$2"
    
    cat > "$config_file" << EOF
server {
    listen 80;
    listen [::]:80;
    server_name ${NGINX_DOMAIN} www.${NGINX_DOMAIN};

    root ${root};
    index index.html index.htm;

    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF
}

# 创建反向代理配置
create_proxy_config() {
    local config_file="$1"
    local root="$2"
    
    cat > "$config_file" << EOF
server {
    listen 80;
    listen [::]:80;
    server_name ${NGINX_DOMAIN} www.${NGINX_DOMAIN};

    location / {
        proxy_pass ${NGINX_BACKEND};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF
}

# 设置 SSL
setup_ssl() {
    print_status "配置 SSL 证书..."
    
    # 安装 Certbot
    if ! command -v certbot &>/dev/null; then
        apt-get install -y certbot python3-certbot-nginx || {
            print_warning "安装 Certbot 失败"
            return 1
        }
    fi
    
    # 申请证书
    if certbot --nginx -d "$NGINX_DOMAIN" --non-interactive --agree-tos --email "admin@${NGINX_DOMAIN}" 2>/dev/null; then
        log "INFO" "SSL 证书申请成功"
        print_success "SSL 配置完成"
    else
        print_warning "SSL 证书申请失败，请检查域名解析"
    fi
}

# 启动 Nginx
start_nginx() {
    print_status "启动 Nginx..."
    
    systemctl enable nginx
    systemctl restart nginx
    
    if systemctl is-active --quiet nginx; then
        log "INFO" "Nginx 已启动"
        print_success "Nginx 运行正常"
    else
        error_exit "Nginx 启动失败"
    fi
}

# 注册模块
register_module \
    --name "nginx" \
    --category "network" \
    --description "安装并配置 Nginx（支持 SSL 和反向代理）" \
    --depends-on "firewall" \
    --config-section "nginx"
