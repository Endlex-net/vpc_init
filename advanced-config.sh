#!/bin/bash

################################################################################
# 服务器高级配置脚本
# 用途: 初始设置后的额外配置
# 功能:
#   - 时区配置
#   - Swap 设置
#   - 安全加固
#   - 系统限制配置
#   - Docker 安装（可选）
#   - Nginx 安装和配置（新增）
#   - BBR 启用（TCP 加速）
#   - Powerlevel10k 安装
################################################################################

set -euo pipefail

# 颜色代码
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 日志
LOG_FILE="/var/log/vpc-init/advanced-config-$(date +%Y%m%d-%H%M%S).log"
LOG_DIR=$(dirname "${LOG_FILE}")

# 全局变量
NGINX_DOMAIN=""
NGINX_ENABLE_SSL=false
NGINX_BACKEND=""

log() {
    local level="$1"
    shift
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [${level}] $*" | tee -a "${LOG_FILE}"
}

print_status() {
    echo -e "${BLUE}==>${NC} $*"
}

print_success() {
    echo -e "${GREEN}✓${NC} $*"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $*"
}

print_info() {
    echo -e "${CYAN}ℹ${NC} $*"
}

error_exit() {
    echo -e "${RED}错误: $*${NC}" >&2
    log "ERROR" "$*"
    exit 1
}

# 检查 root 权限
if [[ $EUID -ne 0 ]]; then
    error_exit "此脚本必须以 root 身份运行"
fi

mkdir -p "${LOG_DIR}"
log "INFO" "高级配置脚本启动"

################################################################################
# 时区配置
################################################################################

configure_timezone() {
    local timezone="${1:-Asia/Shanghai}"
    
    print_status "正在配置时区为 ${timezone}..."
    
    if ! timedatectl set-timezone "${timezone}" 2>/dev/null; then
        error_exit "设置时区失败"
    fi
    
    log "INFO" "时区已设置为 ${timezone}"
    print_success "时区配置完成"
    
    # 显示当前时间
    echo ""
    print_info "当前系统时间: $(date)"
}

################################################################################
# Swap 设置
################################################################################

setup_swap() {
    local swap_size="${1:-2G}"
    local swap_file="/swapfile"
    
    print_status "正在设置 Swap (${swap_size})..."
    
    # 检查是否已存在 swap
    if [[ -f "${swap_file}" ]]; then
        print_status "Swap 文件已存在，跳过"
        log "INFO" "Swap 文件已存在"
        return
    fi
    
    # 检查是否已有其他 swap
    if swapon --show | grep -q "swap"; then
        print_warning "检测到已有 Swap，跳过创建"
        log "INFO" "已有 Swap 存在"
        swapon --show
        return
    fi
    
    # 创建 swap 文件
    print_info "正在创建 ${swap_size} 的 swap 文件..."
    fallocate -l "${swap_size}" "${swap_file}" || \
        error_exit "创建 swap 文件失败"
    
    chmod 600 "${swap_file}"
    mkswap "${swap_file}" || error_exit "格式化 swap 失败"
    swapon "${swap_file}" || error_exit "激活 swap 失败"
    
    # 添加到 fstab
    if ! grep -q "${swap_file}" /etc/fstab; then
        echo "${swap_file} none swap sw 0 0" >> /etc/fstab
    fi
    
    # 优化 swap 配置
    echo "vm.swappiness=10" >> /etc/sysctl.conf
    echo "vm.vfs_cache_pressure=50" >> /etc/sysctl.conf
    sysctl -p
    
    log "INFO" "Swap 配置完成: ${swap_size}"
    print_success "Swap 设置完成"
    
    # 显示状态
    echo ""
    print_info "当前 Swap 状态:"
    free -h | grep -i swap
}

################################################################################
# 安全加固
################################################################################

security_hardening() {
    print_status "正在应用安全加固..."
    
    # 备份 SSH 配置
    if [[ ! -f /etc/ssh/sshd_config.backup ]]; then
        cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
    fi
    
    # 禁用空密码
    sed -i 's/^#*PermitEmptyPasswords.*/PermitEmptyPasswords no/' /etc/ssh/sshd_config
    
    # 禁用 root 登录
    sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
    
    # 限制最大认证尝试次数
    if ! grep -q "^MaxAuthTries" /etc/ssh/sshd_config; then
        echo "MaxAuthTries 3" >> /etc/ssh/sshd_config
    fi
    
    # 重启 SSH 服务
    if systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null; then
        log "INFO" "SSH 服务已重启"
    else
        print_warning "SSH 服务重启失败，请手动检查"
    fi
    
    # 配置防火墙基本规则
    if command -v ufw &>/dev/null; then
        ufw default deny incoming
        ufw default allow outgoing
        ufw allow ssh
        print_info "防火墙规则已更新"
    fi
    
    # 禁用不必要的服务
    local services=("bluetooth" "cups" "avahi-daemon")
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            systemctl stop "$service" 2>/dev/null || true
            systemctl disable "$service" 2>/dev/null || true
            log "INFO" "已禁用服务: $service"
        fi
    done
    
    log "INFO" "安全加固已应用"
    print_success "安全加固完成"
    
    echo ""
    print_info "安全加固项目:"
    echo "  ✓ 禁用空密码登录"
    echo "  ✓ 禁用 root 登录"
    echo "  ✓ 限制最大认证尝试次数为 3"
    echo "  ✓ 配置防火墙默认策略"
    echo "  ✓ 禁用不必要的服务"
}

################################################################################
# 系统限制配置
################################################################################

setup_limits() {
    print_status "正在配置系统限制..."
    
    # 备份原有配置
    if [[ ! -f /etc/security/limits.conf.backup ]]; then
        cp /etc/security/limits.conf /etc/security/limits.conf.backup
    fi
    
    # 添加到 limits.conf
    cat >> /etc/security/limits.conf << 'EOF'

# 为所有用户设置限制
* soft nofile 65535
* hard nofile 65535
* soft nproc 65535
* hard nproc 65535
* soft memlock unlimited
* hard memlock unlimited

# root 用户限制
root soft nofile 65535
root hard nofile 65535
root soft nproc unlimited
root hard nproc unlimited
EOF
    
    # 配置 systemd 限制
    mkdir -p /etc/systemd/system.conf.d/
    cat > /etc/systemd/system.conf.d/limits.conf << 'EOF'
[Manager]
DefaultLimitNOFILE=65535
DefaultLimitNPROC=65535
EOF
    
    # 配置 sysctl
    cat >> /etc/sysctl.conf << 'EOF'

# 系统性能优化
fs.file-max = 2097152
fs.nr_open = 2097152
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 65535
net.ipv4.tcp_max_syn_backlog = 65535
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 1200
net.ipv4.tcp_max_tw_buckets = 5000
EOF
    
    sysctl -p
    
    log "INFO" "系统限制已配置"
    print_success "系统限制配置完成"
    
    echo ""
    print_info "当前限制:"
    ulimit -n
    ulimit -u
}

################################################################################
# Docker 安装
################################################################################

install_docker() {
    print_status "正在安装 Docker..."
    
    if command -v docker &>/dev/null; then
        print_status "Docker 已安装"
        docker --version
        log "INFO" "Docker 已安装"
        return
    fi
    
    # 安装依赖
    print_info "正在安装依赖..."
    apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release || \
        error_exit "安装 Docker 依赖失败"
    
    # 添加 Docker GPG 密钥
    print_info "正在添加 Docker GPG 密钥..."
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg || \
        error_exit "添加 Docker GPG 密钥失败"
    
    # 添加 Docker 仓库
    print_info "正在添加 Docker 仓库..."
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
        tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # 更新并安装 Docker
    print_info "正在安装 Docker..."
    apt-get update || error_exit "更新软件包列表失败"
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin || \
        error_exit "安装 Docker 失败"
    
    # 添加 endlex 用户到 docker 组
    if id "endlex" &>/dev/null; then
        usermod -aG docker endlex || print_warning "添加用户到 docker 组失败"
        print_info "用户 'endlex' 已添加到 docker 组"
    fi
    
    # 启动 Docker
    systemctl enable docker
    systemctl start docker
    
    # 验证安装
    if docker --version &>/dev/null; then
        log "INFO" "Docker 安装成功"
        print_success "Docker 安装成功"
        docker --version
        docker compose version
    else
        error_exit "Docker 安装验证失败"
    fi
    
    echo ""
    print_info "Docker 使用提示:"
    echo "  • 查看 Docker 状态: systemctl status docker"
    echo "  • 使用 Docker: docker ps"
    echo "  • 使用 Docker Compose: docker compose up -d"
    echo "  • 需要重新登录以使用无 sudo 的 Docker 命令"
}

################################################################################
# Nginx 安装和配置（新增）
################################################################################

install_nginx() {
    print_status "正在安装 Nginx..."
    
    # 检查是否已安装
    if command -v nginx &>/dev/null; then
        print_status "Nginx 已安装"
        nginx -v
        log "INFO" "Nginx 已安装"
        return 0
    fi
    
    # 更新软件包列表
    apt-get update || error_exit "更新软件包列表失败"
    
    # 安装 Nginx
    apt-get install -y nginx || error_exit "安装 Nginx 失败"
    
    # 启动 Nginx
    systemctl start nginx
    systemctl enable nginx
    
    # 验证安装
    if systemctl is-active --quiet nginx; then
        log "INFO" "Nginx 安装成功并已启动"
        print_success "Nginx 安装成功"
        nginx -v
    else
        error_exit "Nginx 启动失败"
    fi
    
    # 显示基本信息
    echo ""
    print_info "Nginx 状态:"
    systemctl status nginx --no-pager -l
    
    echo ""
    print_info "Nginx 配置文件位置:"
    echo "  • 主配置: /etc/nginx/nginx.conf"
    echo "  • 站点配置: /etc/nginx/sites-available/"
    echo "  • 启用站点: /etc/nginx/sites-enabled/"
    echo "  • Web 根目录: /var/www/html/"
    
    return 0
}

configure_nginx_site() {
    local domain="${1:-}"
    local enable_ssl="${2:-false}"
    local backend="${3:-}"
    
    if [[ -z "$domain" ]]; then
        print_warning "未提供域名，跳过站点配置"
        return 0
    fi
    
    print_status "正在配置 Nginx 站点: $domain"
    
    # 创建站点目录
    local site_root="/var/www/$domain"
    mkdir -p "$site_root"
    chown -R www-data:www-data "$site_root"
    chmod -R 755 "$site_root"
    
    # 创建默认 index 页面
    cat > "$site_root/index.html" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Welcome to $domain</title>
    <style>
        body { font-family: Arial, sans-serif; text-align: center; padding: 50px; }
        h1 { color: #333; }
        p { color: #666; }
    </style>
</head>
<body>
    <h1>Welcome to $domain!</h1>
    <p>Nginx is successfully installed and working.</p>
    <p>Server configured by vpc_init</p>
</body>
</html>
EOF
    
    # 创建 Nginx 配置
    local config_file="/etc/nginx/sites-available/$domain"
    
    if [[ -n "$backend" ]]; then
        # 反向代理配置
        cat > "$config_file" << EOF
server {
    listen 80;
    listen [::]:80;
    server_name $domain www.$domain;

    access_log /var/log/nginx/$domain-access.log;
    error_log /var/log/nginx/$domain-error.log;

    location / {
        proxy_pass $backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        
        # 超时设置
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # 静态文件缓存
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg)$ {
        proxy_pass $backend;
        expires 30d;
        add_header Cache-Control "public, immutable";
    }
}
EOF
        print_info "已创建反向代理配置: $backend -> $domain"
    else
        # 普通站点配置
        cat > "$config_file" << EOF
server {
    listen 80;
    listen [::]:80;
    server_name $domain www.$domain;

    root $site_root;
    index index.html index.htm index.nginx-debian.html;

    access_log /var/log/nginx/$domain-access.log;
    error_log /var/log/nginx/$domain-error.log;

    location / {
        try_files \$uri \$uri/ =404;
    }

    # 静态文件缓存
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg)$ {
        expires 30d;
        add_header Cache-Control "public, immutable";
    }

    # 安全头
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
}
EOF
        print_info "已创建站点配置: $domain"
    fi
    
    # 启用站点
    if [[ ! -L "/etc/nginx/sites-enabled/$domain" ]]; then
        ln -s "$config_file" "/etc/nginx/sites-enabled/$domain"
    fi
    
    # 测试配置
    if nginx -t; then
        print_success "Nginx 配置测试通过"
    else
        error_exit "Nginx 配置测试失败"
    fi
    
    # 重载 Nginx
    systemctl reload nginx
    
    log "INFO" "Nginx 站点配置完成: $domain"
    print_success "站点 $domain 配置完成"
    
    # 如果启用 SSL，申请证书
    if [[ "$enable_ssl" == "true" ]]; then
        setup_ssl "$domain"
    fi
    
    return 0
}

setup_ssl() {
    local domain="${1:-}"
    
    if [[ -z "$domain" ]]; then
        print_warning "未提供域名，跳过 SSL 配置"
        return 0
    fi
    
    print_status "正在为 $domain 配置 SSL 证书..."
    
    # 安装 Certbot
    if ! command -v certbot &>/dev/null; then
        print_info "正在安装 Certbot..."
        apt-get install -y certbot python3-certbot-nginx || \
            error_exit "安装 Certbot 失败"
    fi
    
    # 申请证书
    print_info "正在申请 Let's Encrypt 证书..."
    print_warning "请确保域名 $domain 已解析到本服务器 IP"
    read -p "域名解析已完成? (y/n) " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_warning "跳过 SSL 配置，您可以稍后手动运行: certbot --nginx -d $domain"
        return 0
    fi
    
    # 使用 Certbot 自动配置
    if certbot --nginx -d "$domain" -d "www.$domain" --non-interactive --agree-tos --email admin@$domain 2>/dev/null; then
        log "INFO" "SSL 证书申请成功: $domain"
        print_success "SSL 证书配置完成"
        
        # 设置自动续期
        systemctl enable certbot.timer
        systemctl start certbot.timer
        
        echo ""
        print_info "SSL 配置信息:"
        echo "  • 证书路径: /etc/letsencrypt/live/$domain/"
        echo "  • 自动续期: 已启用"
        echo "  • 续期测试: certbot renew --dry-run"
    else
        print_warning "证书申请失败，请检查域名解析和防火墙设置"
        print_info "您可以稍后手动运行: certbot --nginx -d $domain"
        return 1
    fi
    
    return 0
}

nginx_full_setup() {
    local domain="${NGINX_DOMAIN:-}"
    local enable_ssl="${NGINX_ENABLE_SSL:-false}"
    local backend="${NGINX_BACKEND:-}"
    
    # 安装 Nginx
    install_nginx
    
    # 配置站点（如果提供了域名）
    if [[ -n "$domain" ]]; then
        configure_nginx_site "$domain" "$enable_ssl" "$backend"
    else
        print_info "未提供域名，仅安装 Nginx，未配置站点"
        print_info "您可以稍后手动配置站点"
    fi
    
    # 显示完成信息
    echo ""
    echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}Nginx 安装和配置完成！${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
    echo ""
    print_info "Nginx 管理命令:"
    echo "  • 查看状态: systemctl status nginx"
    echo "  • 启动: systemctl start nginx"
    echo "  • 停止: systemctl stop nginx"
    echo "  • 重载: systemctl reload nginx"
    echo "  • 测试配置: nginx -t"
    echo ""
    print_info "配置文件位置:"
    echo "  • 主配置: /etc/nginx/nginx.conf"
    echo "  • 站点配置: /etc/nginx/sites-available/"
    echo "  • 启用站点: /etc/nginx/sites-enabled/"
    echo ""
    
    if [[ -n "$domain" ]]; then
        print_info "访问地址:"
        if [[ "$enable_ssl" == "true" ]]; then
            echo "  • https://$domain"
            echo "  • https://www.$domain"
        else
            echo "  • http://$domain"
            echo "  • http://www.$domain"
        fi
    fi
}

################################################################################
# BBR 启用（TCP 加速）
################################################################################

enable_bbr() {
    print_status "正在启用 BBR（TCP 拥塞控制）..."
    
    # 检查是否已启用
    if sysctl net.ipv4.tcp_congestion_control 2>/dev/null | grep -q "bbr"; then
        print_status "BBR 已启用"
        log "INFO" "BBR 已启用"
        sysctl net.ipv4.tcp_congestion_control
        return
    fi
    
    # 检查内核版本（需要 4.9+）
    local kernel_version=$(uname -r | cut -d. -f1,2)
    if [[ "$(echo "$kernel_version >= 4.9" | bc)" -eq 0 ]]; then
        print_warning "内核版本过低 ($kernel_version)，需要 4.9+ 才能启用 BBR"
        print_info "当前内核: $(uname -r)"
        return 1
    fi
    
    # 启用 BBR
    cat >> /etc/sysctl.conf << 'EOF'

# BBR TCP 拥塞控制
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
EOF
    
    # 应用更改
    sysctl -p || error_exit "应用 sysctl 更改失败"
    
    log "INFO" "BBR 启用成功"
    print_success "BBR 已启用"
    
    # 验证
    echo ""
    print_info "BBR 状态:"
    echo "  TCP 拥塞控制算法:"
    sysctl net.ipv4.tcp_congestion_control
    echo "  默认队列规则:"
    sysctl net.core.default_qdisc
}

################################################################################
# Powerlevel10k 安装
################################################################################

install_p10k() {
    print_status "正在安装 Powerlevel10k..."
    
    # 安装 zsh
    if ! command -v zsh &>/dev/null; then
        print_info "正在安装 zsh..."
        apt-get install -y zsh || error_exit "安装 zsh 失败"
        log "INFO" "zsh 安装完成"
    fi
    
    # 安装 oh-my-zsh
    if [[ ! -d /home/endlex/.oh-my-zsh ]]; then
        print_info "正在安装 Oh My Zsh..."
        sudo -u endlex bash -c 'sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended' || \
            print_warning "安装 Oh My Zsh 失败"
    else
        print_status "Oh My Zsh 已安装"
    fi
    
    # 安装 Powerlevel10k
    if [[ ! -d /home/endlex/.oh-my-zsh/custom/themes/powerlevel10k ]]; then
        print_info "正在安装 Powerlevel10k..."
        git clone --depth=1 https://github.com/romkatv/powerlevel10k.git /home/endlex/.oh-my-zsh/custom/themes/powerlevel10k || \
            error_exit "安装 Powerlevel10k 失败"
        
        chown -R endlex:endlex /home/endlex/.oh-my-zsh
        
        # 设置 ZSH_THEME
        sed -i 's/ZSH_THEME=.*/ZSH_THEME="powerlevel10k\/powerlevel10k"/' /home/endlex/.zshrc
        
        log "INFO" "Powerlevel10k 安装成功"
        print_success "Powerlevel10k 安装完成"
    else
        print_status "Powerlevel10k 已安装"
    fi
    
    # 更改默认 shell
    if ! sudo -u endlex sh -c '[[ $SHELL == *zsh* ]]'; then
        chsh -s /usr/bin/zsh endlex || print_warning "更改 shell 为 zsh 失败"
        print_info "默认 shell 已更改为 zsh"
    fi
    
    # 安装推荐字体（可选）
    echo ""
    print_info "Powerlevel10k 安装说明:"
    echo "  • 运行 'p10k configure' 来自定义主题"
    echo "  • 建议安装 Meslo Nerd Font 以获得最佳显示效果"
    echo "  • 推荐字体: Meslo Nerd Font, JetBrains Mono"
    echo ""
    print_info "字体安装方法:"
    echo "  1. 下载 Meslo Nerd Font"
    echo "  2. 安装到本地系统"
    echo "  3. 在终端中设置使用该字体"
}

################################################################################
# 使用说明
################################################################################

show_usage() {
    cat << EOF
用法: $(basename "$0") [选项]

选项:
  --timezone TIMEZONE      设置时区（默认: Asia/Shanghai）
  --swap SIZE              设置 Swap（例如: 2G, 1G）
  --security               启用安全加固
  --limits                 配置系统限制
  --docker                 安装 Docker
  --nginx                  安装 Nginx
  --domain DOMAIN          设置域名（用于 Nginx 配置）
  --ssl                    启用 SSL（配合 --nginx 使用）
  --proxy BACKEND          配置反向代理（例如: http://localhost:3000）
  --bbr                    启用 BBR（TCP 拥塞控制）
  --p10k                   安装 Powerlevel10k（p10k）zsh 主题
  --all                    应用所有配置
  --help, -h               显示此帮助信息

示例:
  # 设置时区和 Swap
  sudo $(basename "$0") --timezone Asia/Shanghai --swap 2G

  # 仅安装 Nginx
  sudo $(basename "$0") --nginx

  # 安装 Nginx 并配置站点（带 SSL）
  sudo $(basename "$0") --nginx --domain example.com --ssl

  # 安装 Nginx 并配置反向代理
  sudo $(basename "$0") --nginx --domain example.com --proxy http://localhost:3000

  # 完整配置（Nginx + SSL + 反向代理）
  sudo $(basename "$0") --nginx --domain example.com --ssl --proxy http://localhost:8080

  # 启用 BBR 和安装 p10k
  sudo $(basename "$0") --bbr --p10k

  # 应用所有配置
  sudo $(basename "$0") --all

EOF
}

################################################################################
# 主函数
################################################################################

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case "$1" in
        --timezone)
            configure_timezone "$2"
            shift 2
            ;;
        --swap)
            setup_swap "$2"
            shift 2
            ;;
        --security)
            security_hardening
            shift
            ;;
        --limits)
            setup_limits
            shift
            ;;
        --docker)
            install_docker
            shift
            ;;
        --nginx)
            install_nginx
            shift
            ;;
        --domain)
            NGINX_DOMAIN="$2"
            shift 2
            ;;
        --ssl)
            NGINX_ENABLE_SSL=true
            shift
            ;;
        --proxy)
            NGINX_BACKEND="$2"
            shift 2
            ;;
        --bbr)
            enable_bbr
            shift
            ;;
        --p10k)
            install_p10k
            shift
            ;;
        --all)
            configure_timezone "Asia/Shanghai"
            setup_swap "2G"
            setup_limits
            security_hardening
            enable_bbr
            install_p10k
            shift
            ;;
        --help|-h)
            show_usage
            exit 0
            ;;
        *)
            echo -e "${RED}未知选项: $1${NC}" >&2
            show_usage
            exit 1
            ;;
    esac
done

# 检查是否需要执行 Nginx 完整配置
if [[ -n "$NGINX_DOMAIN" ]] || [[ "$NGINX_ENABLE_SSL" == "true" ]] || [[ -n "$NGINX_BACKEND" ]]; then
    nginx_full_setup
fi

print_success "高级配置完成"
echo "日志文件: ${LOG_FILE}"
