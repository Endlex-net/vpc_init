#!/bin/bash

################################################################################
# VPC_INIT 核心库
# 提供基础功能和工具函数
################################################################################

set -euo pipefail

# 脚本根目录
# 使用已设置的 VPC_INIT_ROOT，或自动检测
if [[ -z "${VPC_INIT_ROOT:-}" ]]; then
    if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
        VPC_INIT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    else
        VPC_INIT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
    fi
fi

# 颜色代码
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[1;33m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_CYAN='\033[0;36m'
readonly COLOR_NC='\033[0m'

# 日志配置
LOG_DIR="/var/log/vpc-init"
LOG_FILE=""
ERROR_LOG=""

################################################################################
# 日志系统
################################################################################

init_logging() {
    LOG_FILE="${LOG_DIR}/vpc-init-$(date +%Y%m%d-%H%M%S).log"
    ERROR_LOG="${LOG_DIR}/vpc-init-errors-$(date +%Y%m%d-%H%M%S).log"
    
    mkdir -p "${LOG_DIR}"
    touch "${LOG_FILE}" "${ERROR_LOG}"
    chmod 600 "${ERROR_LOG}"
    
    log "INFO" "日志系统初始化完成"
    log "INFO" "主日志: ${LOG_FILE}"
    log "INFO" "错误日志: ${ERROR_LOG}"
}

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    if [[ -n "${LOG_FILE:-}" ]]; then
        echo "[${timestamp}] [${level}] ${message}" | tee -a "${LOG_FILE}"
    else
        echo "[${timestamp}] [${level}] ${message}"
    fi
}

log_error() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    if [[ -n "${ERROR_LOG:-}" && -n "${LOG_FILE:-}" ]]; then
        echo "[${timestamp}] [ERROR] ${message}" | tee -a "${LOG_FILE}" "${ERROR_LOG}" >&2
    else
        echo "[${timestamp}] [ERROR] ${message}" >&2
    fi
}

################################################################################
# 输出函数
################################################################################

print_header() {
    echo -e "\n${COLOR_BLUE}═══════════════════════════════════════════════════════════${COLOR_NC}"
    echo -e "${COLOR_CYAN}$1${COLOR_NC}"
    echo -e "${COLOR_BLUE}═══════════════════════════════════════════════════════════${COLOR_NC}\n"
}

print_status() {
    echo -e "${COLOR_BLUE}==>${COLOR_NC} $*"
}

print_success() {
    echo -e "${COLOR_GREEN}✓${COLOR_NC} $*"
}

print_warning() {
    echo -e "${COLOR_YELLOW}⚠${COLOR_NC} $*"
}

print_info() {
    echo -e "${COLOR_CYAN}ℹ${COLOR_NC} $*"
}

print_error() {
    echo -e "${COLOR_RED}✗${COLOR_NC} $*"
}

################################################################################
# 错误处理
################################################################################

error_exit() {
    local message="$1"
    local exit_code="${2:-1}"
    
    log_error "$message"
    echo -e "${COLOR_RED}错误: ${message}${COLOR_NC}" >&2
    
    if [[ -n "${ERROR_LOG:-}" ]]; then
        echo "======================================" >> "${ERROR_LOG}"
    fi
    
    exit "${exit_code}"
}

################################################################################
# 系统检查
################################################################################

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error_exit "此脚本必须以 root 身份运行，请使用: sudo bash $0"
    fi
    log "INFO" "权限检查通过: root"
}

check_ubuntu() {
    if [[ ! -f /etc/os-release ]]; then
        error_exit "无法确定操作系统"
    fi
    
    . /etc/os-release
    if [[ "$ID" != "ubuntu" ]]; then
        error_exit "此脚本专为 Ubuntu 设计。当前系统: $ID"
    fi
    
    log "INFO" "系统检查通过: Ubuntu $VERSION_ID"
}

check_dpkg() {
    if dpkg --audit &>/dev/null; then
        log "INFO" "dpkg 状态检查通过"
        return 0
    fi
    
    if [[ -f /var/lib/dpkg/updates/0000 ]]; then
        print_warning "dpkg 状态异常，需要修复"
        print_info "请运行: sudo bash ${VPC_INIT_ROOT}/fix-dpkg.sh"
        error_exit "dpkg 需要修复"
    fi
    
    log "INFO" "dpkg 状态检查通过"
}

################################################################################
# 工具函数
################################################################################

confirm() {
    local message="${1:-确认继续?}"
    local default="${2:-Y}"
    
    if [[ "$default" == "Y" ]]; then
        read -p "${message} [Y/n] " -n 1 -r
        echo
        [[ ! $REPLY =~ ^[Nn]$ ]]
    else
        read -p "${message} [y/N] " -n 1 -r
        echo
        [[ $REPLY =~ ^[Yy]$ ]]
    fi
}

validate_username() {
    local username="$1"
    [[ "$username" =~ ^[a-zA-Z_][a-zA-Z0-9_-]{0,31}$ ]]
}

validate_timezone() {
    local tz="$1"
    [[ -d "/usr/share/zoneinfo/$tz" ]]
}

validate_swap_size() {
    local size="$1"
    [[ "$size" =~ ^[0-9]+[GMK]?$ ]]
}

generate_password() {
    openssl rand -base64 32 | sed 's/[^a-zA-Z0-9]//g' | cut -c1-24
}

################################################################################
# 导出函数 (仅 Bash 支持)
################################################################################

if [[ -n "${BASH_VERSION:-}" ]]; then
    # Bash 中导出函数
    export -f log log_error print_header print_status print_success print_warning print_info print_error error_exit
    export -f check_root check_ubuntu check_dpkg
    export -f confirm validate_username validate_timezone validate_swap_size generate_password
fi

export VPC_INIT_ROOT LOG_DIR LOG_FILE ERROR_LOG
export COLOR_RED COLOR_GREEN COLOR_YELLOW COLOR_BLUE COLOR_CYAN COLOR_NC
