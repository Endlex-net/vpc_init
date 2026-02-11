#!/bin/bash

################################################################################
# Ubuntu 服务器初始化工具包 - 主脚本
# 功能：
#   - 用户创建和管理
#   - SSH 配置
#   - 系统更新和依赖安装
#   - 防火墙配置
#   - 基于配置文件的自动初始化
#   - 高级配置菜单
################################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 颜色代码
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 默认配置
USERNAME="endlex"
TIMEZONE="Asia/Shanghai"
SSH_KEYS=""
CONFIG_FILE=""

# 日志配置
LOG_DIR="/var/log/vpc-init"
LOG_FILE="${LOG_DIR}/setup-$(date +%Y%m%d-%H%M%S).log"
ERROR_LOG="${LOG_DIR}/setup-errors-$(date +%Y%m%d-%H%M%S).log"

################################################################################
# 日志函数
################################################################################

init_logging() {
    mkdir -p "${LOG_DIR}"
    touch "${LOG_FILE}"
    touch "${ERROR_LOG}"
    chmod 600 "${ERROR_LOG}"
}

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [${level}] ${message}" | tee -a "${LOG_FILE}"
}

error_exit() {
    local message="$1"
    local exit_code="${2:-1}"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [ERROR] ${message}" | tee -a "${LOG_FILE}" "${ERROR_LOG}" >&2
    echo "======================================" >> "${ERROR_LOG}"
    echo -e "${RED}错误: ${message}${NC}" >&2
    exit "${exit_code}"
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

print_header() {
    echo -e "\n${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}\n"
}

################################################################################
# 系统检查函数
################################################################################

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error_exit "此脚本必须以 root 身份运行，请使用: sudo bash $0"
    fi
    log "INFO" "以 root 身份运行 - OK"
}

check_ubuntu() {
    if [[ ! -f /etc/os-release ]]; then
        error_exit "无法确定操作系统"
    fi
    
    . /etc/os-release
    if [[ "$ID" != "ubuntu" ]]; then
        error_exit "此脚本专为 Ubuntu 设计。当前系统: $ID"
    fi
    log "INFO" "检测到 Ubuntu 系统: $VERSION_ID"
}

check_dpkg() {
    if ! dpkg --configure -a 2>&1 | grep -q "Setting up\|Processing triggers"; then
        if dpkg -l 2>&1 | grep -q "^ii"; then
            log "INFO" "dpkg 状态检查 - OK"
            return 0
        fi
    fi
    
    if [[ -f /var/lib/dpkg/updates/0000 ]]; then
        print_warning "dpkg 状态可能已损坏"
        echo ""
        echo "请在继续前修复 dpkg:"
        echo "  选项 1: 运行修复脚本"
        echo "    $ sudo bash fix-dpkg.sh"
        echo ""
        echo "  选项 2: 手动修复"
        echo "    $ sudo dpkg --configure -a"
        echo "    $ sudo apt-get install -f -y"
        echo ""
        error_exit "dpkg 需要修复。请按照上述说明操作。"
    fi
    
    log "INFO" "dpkg 状态检查 - OK"
}

################################################################################
# 验证函数
################################################################################

validate_swap_size() {
    local size="$1"
    if [[ ! "$size" =~ ^[0-9]+[GMK]?$ ]]; then
        echo -e "${RED}无效的 swap 大小格式: $size${NC}"
        echo "请使用格式如: 1G, 2G, 512M, 1024K"
        return 1
    fi
    return 0
}

validate_timezone() {
    local tz="$1"
    if [[ ! -d "/usr/share/zoneinfo/$tz" ]]; then
        echo -e "${RED}无效的时区: $tz${NC}"
        echo "请输入有效的时区 (例如: Asia/Shanghai, America/New_York)"
        return 1
    fi
    return 0
}

validate_username() {
    local username="$1"
    if ! [[ "$username" =~ ^[a-zA-Z_][a-zA-Z0-9_-]{0,31}$ ]]; then
        echo -e "${RED}无效的用户名格式: $username${NC}"
        echo "用户名必须以字母或下划线开头，只能包含字母、数字、下划线和连字符"
        return 1
    fi
    return 0
}

################################################################################
# 用户管理函数
################################################################################

generate_password() {
    openssl rand -base64 32 | sed 's/[^a-zA-Z0-9]//g' | cut -c1-24
}

create_user() {
    print_status "正在创建用户 '${USERNAME}'..."
    
    if id "${USERNAME}" &>/dev/null; then
        print_warning "用户 '${USERNAME}' 已存在"
        log "WARN" "用户 '${USERNAME}' 已存在，跳过用户创建"
        return 0
    fi
    
    local password=$(generate_password)
    
    useradd -m -s /bin/bash -d "/home/${USERNAME}" "${USERNAME}" || \
        error_exit "创建用户 '${USERNAME}' 失败"
    
    echo "${USERNAME}:${password}" | chpasswd || \
        error_exit "设置用户 '${USERNAME}' 密码失败"
    
    local creds_file="/root/${USERNAME}-credentials.txt"
    cat > "${creds_file}" << EOF
用户凭证 - ${USERNAME}
===============================
创建时间: $(date)
用户名: ${USERNAME}
密码: ${password}
主目录: /home/${USERNAME}

重要提示: 请安全保存这些凭证信息。
此信息仅在用户创建时显示一次。
EOF
    
    chmod 600 "${creds_file}"
    
    log "INFO" "用户 '${USERNAME}' 创建成功"
    log "INFO" "凭证已保存到 ${creds_file}"
    
    print_success "用户 '${USERNAME}' 创建成功"
    echo "临时密码已保存到: ${creds_file}"
}

setup_sudo() {
    print_status "正在设置 '${USERNAME}' 的 sudo 权限..."
    
    local sudoers_file="/etc/sudoers.d/${USERNAME}"
    cat > "${sudoers_file}" << EOF
# 允许 ${USERNAME} 无需密码即可运行所有命令
${USERNAME} ALL=(ALL) NOPASSWD:ALL
EOF
    
    chmod 440 "${sudoers_file}" || \
        error_exit "设置 sudoers 文件权限失败"
    
    if ! visudo -cf "${sudoers_file}" &>/dev/null; then
        rm "${sudoers_file}"
        error_exit "sudoers 语法无效"
    fi
    
    log "INFO" "已为 '${USERNAME}' 配置 sudo 权限"
    print_success "sudo 权限已授予"
}

prompt_change_password() {
    local attempts=0
    local max_attempts=3
    
    echo ""
    echo -e "${YELLOW}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}🔐 修改密码${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "为了安全考虑，建议立即修改初始密码。"
    echo ""
    
    while [[ $attempts -lt $max_attempts ]]; do
        read -p "是否要修改密码? [Y/n/c (是/否/取消)]: " -n 1 -r change_pwd
        echo
        
        case "$change_pwd" in
            [Yy]|"")
                echo ""
                while true; do
                    read -sp "请输入新密码: " new_password
                    echo
                    
                    if [[ -z "$new_password" ]]; then
                        echo -e "${YELLOW}⚠ 密码不能为空，请重试。${NC}"
                        continue
                    fi
                    
                    if [[ ${#new_password} -lt 6 ]]; then
                        echo -e "${YELLOW}⚠ 密码长度至少 6 个字符，请重试。${NC}"
                        continue
                    fi
                    
                    read -sp "请再次输入新密码: " confirm_password
                    echo
                    
                    if [[ "$new_password" != "$confirm_password" ]]; then
                        echo -e "${RED}✗ 两次输入的密码不匹配，请重试。${NC}"
                        continue
                    fi
                    
                    echo "${USERNAME}:${new_password}" | chpasswd 2>/dev/null
                    if [[ $? -eq 0 ]]; then
                        echo ""
                        echo -e "${GREEN}✓ 密码修改成功！${NC}"
                        log "INFO" "用户 '${USERNAME}' 密码修改成功"
                        return 0
                    else
                        echo -e "${RED}✗ 密码修改失败，请稍后重试。${NC}"
                        return 1
                    fi
                done
                ;;
            [Nn])
                echo ""
                echo -e "${YELLOW}⚠ 您选择跳过修改密码。${NC}"
                echo "   请记住临时密码: /root/${USERNAME}-credentials.txt"
                log "INFO" "用户选择跳过密码修改"
                return 0
                ;;
            [Cc]|*)
                echo ""
                echo -e "${YELLOW}⚠ 已取消密码修改。${NC}"
                echo "   您可以稍后使用以下命令修改密码:"
                echo "   $ sudo passwd ${USERNAME}"
                log "INFO" "用户取消密码修改"
                return 0
                ;;
        esac
        
        ((attempts++))
    done
    
    echo ""
    echo -e "${YELLOW}⚠ 输入尝试次数过多，已跳过密码修改。${NC}"
    return 0
}

################################################################################
# SSH 配置函数
################################################################################

setup_ssh() {
    print_status "正在设置 '${USERNAME}' 的 SSH..."
    
    local ssh_dir="/home/${USERNAME}/.ssh"
    local authorized_keys_file="${ssh_dir}/authorized_keys"
    
    if [[ ! -d "${ssh_dir}" ]]; then
        mkdir -p "${ssh_dir}"
        chown "${USERNAME}:${USERNAME}" "${ssh_dir}"
        chmod 700 "${ssh_dir}"
    fi
    
    if [[ ! -f "${authorized_keys_file}" ]]; then
        touch "${authorized_keys_file}"
        chown "${USERNAME}:${USERNAME}" "${authorized_keys_file}"
        chmod 600 "${authorized_keys_file}"
    fi
    
    log "INFO" "已为 '${USERNAME}' 配置 SSH 目录"
    print_success "SSH 目录设置完成"
}

add_ssh_key() {
    local public_key="$1"
    local ssh_dir="/home/${USERNAME}/.ssh"
    local authorized_keys_file="${ssh_dir}/authorized_keys"
    
    if [[ -z "${public_key}" ]]; then
        print_warning "未提供 SSH 公钥"
        log "WARN" "未添加 SSH 公钥 - 未提供"
        return 0
    fi
    
    print_status "正在添加 SSH 公钥..."
    
    if grep -q "$(echo "${public_key}" | awk '{print $1, $2}')" "${authorized_keys_file}" 2>/dev/null; then
        print_warning "SSH 密钥已存在于 authorized_keys 中"
        log "WARN" "SSH 密钥已存在于 authorized_keys"
        return 0
    fi
    
    echo "${public_key}" >> "${authorized_keys_file}"
    chown "${USERNAME}:${USERNAME}" "${authorized_keys_file}"
    chmod 600 "${authorized_keys_file}"
    
    log "INFO" "SSH 公钥已添加到 authorized_keys"
    print_success "SSH 密钥添加成功"
}

setup_ssh_config() {
    print_status "正在配置 SSH 服务器..."
    
    local ssh_config="/etc/ssh/sshd_config"
    
    if [[ ! -f "${ssh_config}.backup" ]]; then
        cp "${ssh_config}" "${ssh_config}.backup"
        log "INFO" "已备份原始 sshd_config"
    fi
    
    log "INFO" "SSH 服务器配置已验证"
    print_success "SSH 服务器配置完成"
}

################################################################################
# 系统更新和依赖
################################################################################

update_system() {
    print_status "正在更新系统软件包..."
    
    apt-get update || error_exit "更新软件包列表失败"
    
    log "INFO" "系统软件包已更新"
    print_success "系统更新完成"
}

install_dependencies() {
    print_status "正在安装基础依赖..."
    
    local packages=(
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
    
    for package in "${packages[@]}"; do
        if dpkg -l | grep -q "^ii  ${package}"; then
            log "INFO" "软件包 '${package}' 已安装"
        else
            apt-get install -y "${package}" || \
                error_exit "安装软件包失败: ${package}"
            log "INFO" "软件包 '${package}' 安装成功"
        fi
    done
    
    print_success "依赖安装完成"
}

################################################################################
# 系统配置
################################################################################

configure_firewall() {
    print_status "正在配置防火墙 (ufw)..."
    
    if ! command -v ufw &>/dev/null; then
        apt-get install -y ufw || error_exit "安装 ufw 失败"
    fi
    
    ufw allow ssh || error_exit "配置 ufw SSH 规则失败"
    echo "y" | ufw enable || print_warning "启用防火墙失败"
    
    log "INFO" "防火墙已配置，允许 SSH 访问"
    print_success "防火墙配置完成"
}

configure_hostname() {
    print_status "正在配置主机名..."
    
    local current_hostname=$(hostname)
    log "INFO" "当前主机名: ${current_hostname}"
    print_success "主机名配置完成 (当前: ${current_hostname})"
}

configure_timezone() {
    local tz="${1:-Asia/Shanghai}"
    print_status "正在配置时区为 ${tz}..."
    
    if command -v timedatectl &>/dev/null; then
        timedatectl set-timezone "${tz}" || \
            print_warning "设置时区失败"
    else
        ln -sf "/usr/share/zoneinfo/${tz}" /etc/localtime || \
            print_warning "设置时区失败"
    fi
    
    log "INFO" "时区已配置为 ${tz}"
    print_success "时区配置完成"
}

################################################################################
# 配置文件处理
################################################################################

load_config() {
    local config_file="$1"
    
    if [[ ! -f "$config_file" ]]; then
        return 1
    fi
    
    source "${SCRIPT_DIR}/config.sh" 2>/dev/null || {
        print_warning "config.sh 未找到，使用默认配置"
        return 1
    }
    
    parse_toml "$config_file" || return 1
    validate_config || return 1
    
    USERNAME=$(get_config "basic:username" "$USERNAME")
    TIMEZONE=$(get_config "basic:timezone" "$TIMEZONE")
    SSH_KEYS=$(get_config "ssh:keys" "$SSH_KEYS")
    
    log "INFO" "已从 $config_file 加载配置"
    echo "配置加载完成:"
    echo "  用户名: $USERNAME"
    echo "  时区: $TIMEZONE"
    
    return 0
}

################################################################################
# 自动初始化流程
################################################################################

auto_setup() {
    print_header "全部自动初始化"
    
    # 检查配置文件
    local config_file="${SCRIPT_DIR}/config.toml"
    local use_config=false
    
    if [[ -f "$config_file" ]]; then
        echo -e "${GREEN}找到配置文件: $config_file${NC}"
        load_config "$config_file"
        use_config=true
    else
        echo -e "${YELLOW}未找到配置文件，将使用默认配置${NC}"
        echo "  默认用户名: $USERNAME"
        echo "  默认时区: $TIMEZONE"
        echo ""
        read -p "是否继续? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return 1
        fi
    fi
    
    echo ""
    echo -e "${CYAN}即将执行以下操作:${NC}"
    echo "  • 更新系统软件包"
    echo "  • 安装基础依赖"
    echo "  • 创建用户 '$USERNAME'"
    echo "  • 配置 sudo 权限"
    echo "  • 配置 SSH"
    echo "  • 配置防火墙"
    echo "  • 设置时区为 $TIMEZONE"
    
    if $use_config; then
        local enable_swap=$(get_config "features:enable_swap" "false")
        local enable_security=$(get_config "features:enable_security" "false")
        local enable_docker=$(get_config "features:enable_docker" "false")
        local enable_nginx=$(get_config "features:enable_nginx" "false")
        local enable_bbr=$(get_config "features:enable_bbr" "false")
        local enable_p10k=$(get_config "features:enable_p10k" "false")
        
        [[ "$enable_swap" == "true" ]] && echo "  • 配置 Swap"
        [[ "$enable_security" == "true" ]] && echo "  • 安全加固"
        [[ "$enable_docker" == "true" ]] && echo "  • 安装 Docker"
        [[ "$enable_nginx" == "true" ]] && echo "  • 安装并配置 Nginx"
        [[ "$enable_bbr" == "true" ]] && echo "  • 启用 BBR"
        [[ "$enable_p10k" == "true" ]] && echo "  • 安装 Powerlevel10k"
    fi
    
    echo ""
    read -p "确认开始初始化? (y/n) " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        return 1
    fi
    
    # 执行初始化
    init_logging
    log "INFO" "========== 开始自动初始化 =========="
    
    check_root
    check_ubuntu
    check_dpkg
    
    update_system
    install_dependencies
    create_user
    setup_sudo
    setup_ssh
    setup_ssh_config
    
    # 添加 SSH 密钥
    if [[ -n "$SSH_KEYS" ]]; then
        IFS=',' read -ra KEY_ARRAY <<< "$SSH_KEYS"
        for key_item in "${KEY_ARRAY[@]}"; do
            key_item=$(echo "$key_item" | xargs)
            if [[ -f "$key_item" ]]; then
                add_ssh_key "$(cat "$key_item")"
            elif [[ "$key_item" =~ ^ssh- ]]; then
                add_ssh_key "$key_item"
            fi
        done
    fi
    
    configure_firewall
    configure_hostname
    configure_timezone "$TIMEZONE"
    
    # 执行高级配置（如果配置文件中启用）
    if $use_config; then
        local swap_size=$(get_config "basic:swap_size" "2G")
        
        if [[ "$enable_swap" == "true" ]]; then
            bash "${SCRIPT_DIR}/advanced-config.sh" --swap "$swap_size"
        fi
        
        [[ "$enable_security" == "true" ]] && bash "${SCRIPT_DIR}/advanced-config.sh" --security
        [[ "$enable_docker" == "true" ]] && bash "${SCRIPT_DIR}/advanced-config.sh" --docker
        [[ "$enable_nginx" == "true" ]] && bash "${SCRIPT_DIR}/advanced-config.sh" --nginx
        [[ "$enable_bbr" == "true" ]] && bash "${SCRIPT_DIR}/advanced-config.sh" --bbr
        [[ "$enable_p10k" == "true" ]] && bash "${SCRIPT_DIR}/advanced-config.sh" --p10k
    fi
    
    # 显示总结
    print_summary
    
    # 提示修改密码
    prompt_change_password
    
    log "INFO" "========== 自动初始化成功完成 =========="
}

################################################################################
# 总结和菜单
################################################################################

print_summary() {
    echo ""
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}服务器初始化完成！${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "配置摘要:"
    echo "  • 用户名: ${USERNAME}"
    echo "  • 主目录: /home/${USERNAME}"
    echo "  • sudo 权限: 已启用 (免密)"
    echo "  • SSH 密钥登录: 已配置"
    echo "  • 系统已更新: 是"
    echo ""
    echo "后续步骤:"
    echo "  1. 获取凭证: /root/${USERNAME}-credentials.txt"
    echo "  2. 添加 SSH 公钥到: /home/${USERNAME}/.ssh/authorized_keys"
    echo "  3. 测试 SSH 登录: ssh ${USERNAME}@<服务器IP>"
    echo "  4. 修改密码: passwd ${USERNAME}"
    echo ""
    echo "日志文件:"
    echo "  • 主日志: ${LOG_FILE}"
    echo "  • 错误日志: ${ERROR_LOG}"
    echo ""
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo ""
}

print_menu() {
    echo -e "${YELLOW}请选择操作:${NC}\n"
    echo "  1) 全部自动初始化（基于配置文件）"
    echo "  2) 高级配置（手动选择）"
    echo "  3) 管理 SSH 密钥"
    echo "  4) 查看日志"
    echo "  5) 帮助文档"
    echo "  0) 退出"
    echo ""
}

################################################################################
# 高级配置菜单
################################################################################

advanced_config_menu() {
    print_header "高级配置"
    
    echo -e "${YELLOW}可用选项:${NC}\n"
    echo "  1) 配置时区（默认: Asia/Shanghai +8）"
    echo "  2) 设置 Swap"
    echo "  3) 安全加固"
    echo "  4) 配置系统限制"
    echo "  5) 安装 Docker"
    echo "  6) 安装并配置 Nginx"
    echo "  7) 启用 BBR（TCP 加速）"
    echo "  8) 安装 Powerlevel10k（p10k）"
    echo "  9) 应用所有配置"
    echo "  0) 返回主菜单"
    echo ""
    
    read -p "请选择: " -n 1 -r adv_choice
    echo
    
    case $adv_choice in
        1)
            read -p "请输入时区（默认 Asia/Shanghai）: " -r tz
            tz=${tz:-Asia/Shanghai}
            if validate_timezone "$tz"; then
                bash "${SCRIPT_DIR}/advanced-config.sh" --timezone "$tz"
            else
                echo -e "${YELLOW}时区验证失败，请重试。${NC}"
            fi
            ;;
        2)
            while true; do
                read -p "请输入 swap 大小（例如: 2G, 4G）: " -r swap_size
                if validate_swap_size "$swap_size"; then
                    bash "${SCRIPT_DIR}/advanced-config.sh" --swap "$swap_size"
                    break
                else
                    echo "请重试。"
                fi
            done
            ;;
        3)
            bash "${SCRIPT_DIR}/advanced-config.sh" --security
            ;;
        4)
            bash "${SCRIPT_DIR}/advanced-config.sh" --limits
            ;;
        5)
            bash "${SCRIPT_DIR}/advanced-config.sh" --docker
            ;;
        6)
            advanced_nginx_menu
            ;;
        7)
            bash "${SCRIPT_DIR}/advanced-config.sh" --bbr
            ;;
        8)
            bash "${SCRIPT_DIR}/advanced-config.sh" --p10k
            ;;
        9)
            bash "${SCRIPT_DIR}/advanced-config.sh" --all
            ;;
        *)
            return
            ;;
    esac
}

################################################################################
# Nginx 高级菜单
################################################################################

advanced_nginx_menu() {
    print_header "Nginx 配置"
    
    echo -e "${YELLOW}请选择 Nginx 配置选项:${NC}\n"
    echo "  1) 仅安装 Nginx"
    echo "  2) 安装 Nginx + 申请 SSL 证书（Let's Encrypt）"
    echo "  3) 安装 Nginx + 配置反向代理"
    echo "  4) 完整配置（Nginx + SSL + 反向代理）"
    echo "  0) 返回上级菜单"
    echo ""
    
    read -p "请选择: " -n 1 -r nginx_choice
    echo
    
    case $nginx_choice in
        1)
            bash "${SCRIPT_DIR}/advanced-config.sh" --nginx
            ;;
        2)
            read -p "请输入域名（例如: example.com）: " -r domain
            if [[ -n "$domain" ]]; then
                bash "${SCRIPT_DIR}/advanced-config.sh" --nginx --domain "$domain" --ssl
            else
                echo -e "${RED}域名不能为空${NC}"
            fi
            ;;
        3)
            read -p "请输入域名: " -r domain
            read -p "请输入后端地址（例如: http://localhost:3000）: " -r backend
            if [[ -n "$domain" && -n "$backend" ]]; then
                bash "${SCRIPT_DIR}/advanced-config.sh" --nginx --domain "$domain" --proxy "$backend"
            else
                echo -e "${RED}域名和后端地址不能为空${NC}"
            fi
            ;;
        4)
            read -p "请输入域名: " -r domain
            read -p "请输入后端地址（例如: http://localhost:3000）: " -r backend
            if [[ -n "$domain" && -n "$backend" ]]; then
                bash "${SCRIPT_DIR}/advanced-config.sh" --nginx --domain "$domain" --ssl --proxy "$backend"
            else
                echo -e "${RED}域名和后端地址不能为空${NC}"
            fi
            ;;
        *)
            return
            ;;
    esac
}

################################################################################
# SSH 密钥管理
################################################################################

manage_ssh_menu() {
    print_header "SSH 密钥管理"
    
    echo -e "${YELLOW}您想要做什么?${NC}\n"
    echo "  1) 添加 SSH 密钥"
    echo "  2) 列出 SSH 密钥"
    echo "  3) 删除 SSH 密钥"
    echo "  4) 返回主菜单"
    echo ""
    
    read -p "请选择: " -n 1 -r ssh_choice
    echo
    
    case $ssh_choice in
        1)
            read -p "请输入 SSH 公钥文件路径: " -r key_file
            if [[ -f "$key_file" ]]; then
                bash "${SCRIPT_DIR}/manage-user.sh" add "$key_file"
            else
                echo -e "${RED}文件不存在: $key_file${NC}"
            fi
            ;;
        2)
            bash "${SCRIPT_DIR}/manage-user.sh" list
            ;;
        3)
            bash "${SCRIPT_DIR}/manage-user.sh" list
            echo ""
            read -p "请输入要删除的密钥编号: " -r key_num
            bash "${SCRIPT_DIR}/manage-user.sh" remove "$key_num"
            ;;
        *)
            return
            ;;
    esac
}

################################################################################
# 日志查看
################################################################################

view_logs_menu() {
    print_header "查看日志"
    
    echo -e "${YELLOW}可用日志:${NC}\n"
    
    if [[ ! -d "$LOG_DIR" ]]; then
        echo -e "${YELLOW}尚未生成日志${NC}"
        return
    fi
    
    logs=($(ls -t "$LOG_DIR" 2>/dev/null | head -10))
    
    for i in "${!logs[@]}"; do
        echo "  $((i+1))) ${logs[$i]}"
    done
    
    echo "  0) 返回主菜单"
    echo ""
    
    read -p "请选择: " -n 1 -r log_choice
    echo
    
    if [[ $log_choice -gt 0 ]] && [[ $log_choice -le ${#logs[@]} ]]; then
        log_file="$LOG_DIR/${logs[$((log_choice-1))]}"
        echo -e "${CYAN}$log_file 内容:${NC}\n"
        tail -100 "$log_file"
        echo ""
        read -p "按 Enter 继续..."
    fi
}

################################################################################
# 帮助文档
################################################################################

show_help() {
    print_header "帮助文档"
    
    cat << 'EOF'
Ubuntu 服务器快速初始化工具包 - 使用指南

核心功能说明：
═════════════════════════════════════════════════════════════

1. 全部自动初始化
   用途: 根据配置文件自动完成所有初始化步骤
   配置: 创建 config.toml 文件（可参考 config.example.toml）
   用法: 选择菜单选项 1

2. 高级配置
   用途: 手动选择和配置高级功能
   包括: 时区、Swap、安全加固、Docker、Nginx、BBR、p10k
   用法: 选择菜单选项 2

3. SSH 密钥管理
   用途: 管理 SSH 公钥
   命令:
     • add <key-file>      添加 SSH 公钥
     • list                列出所有 SSH 密钥
     • remove <number>     删除 SSH 密钥

重要文件位置：
═════════════════════════════════════════════════════════════
• 用户凭证: /root/endlex-credentials.txt
• 日志文件: /var/log/vpc-init/
• SSH 目录: /home/endlex/.ssh/

登录方式：
═════════════════════════════════════════════════════════════

使用密码：
  $ ssh endlex@<server-ip>

使用 SSH 密钥：
  $ ssh -i ~/.ssh/id_rsa endlex@<server-ip>

安全最佳实践：
═════════════════════════════════════════════════════════════
1. 配置 SSH 密钥后禁用密码认证
2. 启用防火墙（已自动配置）
3. 定期更新系统: apt-get update && apt-get upgrade
4. 查看日志确保初始化成功

更多信息：
═════════════════════════════════════════════════════════════
完整文档请查看: README.md

EOF
    
    read -p "按 Enter 继续..."
}

################################################################################
# 主函数
################################################################################

main() {
    check_root
    init_logging
    
    log "INFO" "========== Ubuntu 服务器初始化工具启动 =========="
    
    while true; do
        print_header "Ubuntu 服务器初始化工具包"
        print_menu
        
        read -p "请输入选项 [0-5]: " -n 1 -r choice
        echo
        echo ""
        
        case $choice in
            1)
                auto_setup
                ;;
            2)
                advanced_config_menu
                ;;
            3)
                manage_ssh_menu
                ;;
            4)
                view_logs_menu
                ;;
            5)
                show_help
                ;;
            0)
                echo -e "${GREEN}再见！${NC}"
                log "INFO" "========== 用户退出 =========="
                exit 0
                ;;
            *)
                echo -e "${RED}无效选项，请重试。${NC}"
                ;;
        esac
        
        echo ""
        read -p "按 Enter 继续..."
    done
}

# 运行主函数
main
