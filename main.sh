#!/bin/bash

################################################################################
# VPC_INIT 主入口脚本 v3.0
# 模块化架构设计，支持自动发现和注册
################################################################################

# 检查 Shell 版本
# 检测当前使用的 Shell
CURRENT_SHELL=$(ps -p $$ -o comm= 2>/dev/null || echo "$SHELL")

if [[ -n "$BASH_VERSION" ]]; then
    # 在 Bash 中运行
    if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]; then
        echo ""
        echo "╔══════════════════════════════════════════════════════════════╗"
        echo "║  ⚠️  Bash 版本过低                                           ║"
        echo "╚══════════════════════════════════════════════════════════════╝"
        echo ""
        echo "当前 Bash 版本: $BASH_VERSION"
        echo "需要: Bash 4.0+（支持关联数组）"
        echo ""
        echo "解决方案:"
        echo "  1. 使用 Zsh:   zsh $0"
        echo "  2. 安装新 Bash: brew install bash"
        echo "  3. 在 Ubuntu 服务器上运行此脚本"
        echo ""
        exit 1
    fi
elif [[ -n "$ZSH_VERSION" ]]; then
    # 在 Zsh 中运行
    if [[ "${ZSH_VERSION%%.*}" -lt 5 ]]; then
        echo ""
        echo "╔══════════════════════════════════════════════════════════════╗"
        echo "║  ⚠️  Zsh 版本过低                                            ║"
        echo "╚══════════════════════════════════════════════════════════════╝"
        echo ""
        echo "当前 Zsh 版本: $ZSH_VERSION"
        echo "需要: Zsh 5.0+"
        echo ""
        exit 1
    fi
    echo ""
    echo "ℹ️  检测到 Zsh，将以兼容模式运行"
    echo ""
else
    echo ""
    echo "⚠️  未知的 Shell: $CURRENT_SHELL"
    echo "建议使用 Bash 4.0+ 或 Zsh 5.0+"
    echo ""
    exit 1
fi

set -euo pipefail

# 跨 Shell 获取脚本路径
if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
elif [[ -n "${ZSH_SCRIPT:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "$ZSH_SCRIPT")" && pwd)"
else
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
fi
VPC_INIT_ROOT="$SCRIPT_DIR"

# 加载核心库
source "${SCRIPT_DIR}/lib/core.sh"
source "${SCRIPT_DIR}/lib/checkpoint.sh"
source "${SCRIPT_DIR}/lib/registry.sh"
source "${SCRIPT_DIR}/lib/loader.sh"

# 默认配置
CONFIG_FILE="${SCRIPT_DIR}/config.toml"
INTERACTIVE_MODE=false
VERBOSE_MODE=false

################################################################################
# 帮助信息
################################################################################

show_help() {
    cat << EOF
VPC_INIT - Ubuntu 服务器初始化工具 v3.0

用法:
    sudo bash main.sh [选项] [命令]

命令:
    init                    执行初始化（根据配置或交互式）
    modules                 列出所有可用模块
    install <模块名>        安装指定模块
    config                  生成默认配置文件

选项:
    -c, --config <文件>     指定配置文件（默认: config.toml）
    -i, --interactive       交互式模式
    -v, --verbose           详细输出
    -h, --help              显示帮助
    --version               显示版本

示例:
    # 基础初始化
    sudo bash main.sh init

    # 使用自定义配置
    sudo bash main.sh init -c my-config.toml

    # 交互式选择模块
    sudo bash main.sh init -i

    # 列出所有模块
    sudo bash main.sh modules

    # 单独安装 Nginx
    sudo bash main.sh install nginx

EOF
}

show_version() {
    echo "VPC_INIT v3.0 - 模块化架构"
}

################################################################################
# 初始化流程
################################################################################

cmd_init() {
    print_header "Ubuntu 服务器初始化工具"
    
    # 系统检查
    check_root
    check_ubuntu
    check_dpkg
    
    # 初始化日志和断点系统
    init_logging
    init_checkpoint
    log "INFO" "开始初始化流程"
    
    # 检查是否从断点恢复
    check_resume
    
    # 初始化模块系统
    initialize_modules
    
    # 执行模式
    if [[ "$INTERACTIVE_MODE" == true ]]; then
        # 交互式模式
        log "INFO" "进入交互式模式"
        select_modules_interactive
    elif [[ -f "$CONFIG_FILE" ]]; then
        # 配置驱动模式
        log "INFO" "使用配置文件: $CONFIG_FILE"
        execute_modules_from_config "$CONFIG_FILE"
    else
        # 默认模式：执行核心模块
        log "INFO" "未找到配置文件，执行默认模块"
        execute_default_modules
    fi
    
    print_header "初始化完成！"
    log "INFO" "初始化流程结束"
    
    return 0
}

# 执行默认模块
execute_default_modules() {
    local default_modules=("system" "user" "ssh" "firewall")
    
    print_info "将要执行的默认模块: ${default_modules[*]}"
    
    if ! confirm "确认执行?" "Y"; then
        return 0
    fi
    
    for module in "${default_modules[@]}"; do
        if is_module_registered "$module"; then
            # 使用带断点的执行方式
            if ! execute_module_with_checkpoint "$module"; then
                log_error "模块执行失败: $module"
                if ! confirm "是否继续?" "Y"; then
                    return 1
                fi
            fi
        fi
    done
}

################################################################################
# 模块管理
################################################################################

cmd_modules() {
    print_header "可用模块列表"
    
    # 初始化（不执行）
    initialize_modules 2>/dev/null || true
    
    # 列出模块
    list_modules
    
    return 0
}

cmd_install() {
    local module_name="${1:-}"
    
    if [[ -z "$module_name" ]]; then
        error_exit "请指定要安装的模块名"
    fi
    
    print_header "安装模块: $module_name"
    
    # 初始化
    initialize_modules
    
    # 检查模块是否存在
    if ! is_module_registered "$module_name"; then
        error_exit "模块不存在: $module_name"
    fi
    
    # 执行模块
    if execute_module "$module_name"; then
        print_success "模块安装成功: $module_name"
    else
        error_exit "模块安装失败: $module_name"
    fi
    
    return 0
}

cmd_config() {
    print_header "生成配置文件"
    
    local config_file="${1:-config.toml}"
    
    if [[ -f "$config_file" ]]; then
        if ! confirm "配置文件已存在，是否覆盖?" "N"; then
            return 0
        fi
    fi
    
    cat > "$config_file" << 'EOF'
[basic]
username = "endlex"
timezone = "Asia/Shanghai"

[features]
enable_firewall = true
enable_nginx = false
enable_docker = false
enable_swap = false
enable_security = false
enable_p10k = false

[nginx]
domain = ""
enable_ssl = false
proxy_pass = ""
EOF
    
    print_success "配置文件已生成: $config_file"
    print_info "请编辑配置文件，然后运行: sudo bash main.sh init"
    
    return 0
}

################################################################################
# 参数解析
################################################################################

parse_args() {
    COMMAND=""
    COMMAND_ARGS=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -c|--config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            -i|--interactive)
                INTERACTIVE_MODE=true
                shift
                ;;
            -v|--verbose)
                VERBOSE_MODE=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            --version)
                show_version
                exit 0
                ;;
            init|modules|install|config)
                if [[ -z "$COMMAND" ]]; then
                    COMMAND="$1"
                else
                    COMMAND_ARGS+=("$1")
                fi
                shift
                ;;
            *)
                COMMAND_ARGS+=("$1")
                shift
                ;;
        esac
    done
}

################################################################################
# 主程序
################################################################################

main() {
    # 解析参数
    parse_args "$@"
    
    # 如果没有命令，显示帮助
    if [[ -z "${COMMAND:-}" ]]; then
        show_help
        exit 0
    fi
    
    # 执行命令
    case "$COMMAND" in
        init)
            cmd_init
            ;;
        modules)
            cmd_modules
            ;;
        install)
            cmd_install "${COMMAND_ARGS[@]}"
            ;;
        config)
            cmd_config "${COMMAND_ARGS[@]}"
            ;;
        *)
            error_exit "未知命令: $COMMAND"
            ;;
    esac
    
    exit 0
}

# 运行主程序
main "$@"
