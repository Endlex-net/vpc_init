#!/bin/bash

################################################################################
# VPC_INIT 模块加载器
# 自动发现和加载模块
################################################################################

# 模块搜索路径
MODULE_PATHS=(
    "${VPC_INIT_ROOT}/modules/00-core"
    "${VPC_INIT_ROOT}/modules/10-network"
    "${VPC_INIT_ROOT}/modules/20-runtime"
    "${VPC_INIT_ROOT}/modules/30-tools"
)

################################################################################
# 自动发现模块
################################################################################

# 扫描目录中的模块文件
discover_modules() {
    log "INFO" "开始扫描模块..."
    
    local count=0
    
    for module_dir in "${MODULE_PATHS[@]}"; do
        if [[ ! -d "$module_dir" ]]; then
            continue
        fi
        
        log "DEBUG" "扫描目录: $module_dir"
        
        # 遍历目录中的所有 .sh 文件
        for module_file in "$module_dir"/*.sh; do
            if [[ ! -f "$module_file" ]]; then
                continue
            fi
            
            local module_name=$(basename "$module_file" .sh)
            
            # 检查是否已经注册
            if is_module_registered "$module_name"; then
                continue
            fi
            
            # 尝试从文件中提取元数据
            local category=$(extract_module_metadata "$module_file" "category")
            local description=$(extract_module_metadata "$module_file" "description")
            local depends=$(extract_module_metadata "$module_file" "depends")
            
            # 如果未提取到元数据，使用默认值
            if [[ -z "$category" ]]; then
                category=$(infer_category "$module_dir")
            fi
            
            if [[ -z "$description" ]]; then
                description="$module_name 模块"
            fi
            
            # 注册模块
            register_module \
                --name "$module_name" \
                --category "$category" \
                --description "$description" \
                --depends-on "$depends" \
                --file "$module_file"
            
            count=$((count+1))
        done
    done
    
    log "INFO" "扫描完成，发现 $count 个新模块"
    return 0
}

# 从模块文件中提取元数据
extract_module_metadata() {
    local file="$1"
    local key="$2"
    
    # 查找 # @key: value 格式的注释
    grep -E "^# @${key}:" "$file" 2>/dev/null | head -1 | sed "s/^# @${key}:\s*//"
}

# 从目录路径推断分类
infer_category() {
    local dir="$1"
    
    case "$dir" in
        *00-core*)    echo "core" ;;
        *10-network*) echo "network" ;;
        *20-runtime*) echo "runtime" ;;
        *30-tools*)   echo "tools" ;;
        *)            echo "other" ;;
    esac
}

################################################################################
# 模块初始化
################################################################################

# 初始化所有模块
initialize_modules() {
    log "INFO" "开始初始化模块系统..."
    
    # 1. 发现模块
    discover_modules
    
    # 2. 加载所有模块
    load_all_modules
    
    # 3. 验证依赖
    verify_dependencies
    
    print_success "模块系统初始化完成"
    return 0
}

# 验证模块依赖
verify_dependencies() {
    log "INFO" "验证模块依赖..."
    
    local errors=()
    
    for name in "${!MODULE_DEPENDS[@]}"; do
        local deps="${MODULE_DEPENDS[$name]}"
        
        if [[ -z "$deps" ]]; then
            continue
        fi
        
        # 检查每个依赖
        IFS=',' read -ra DEP_ARRAY <<< "$deps"
        for dep in "${DEP_ARRAY[@]}"; do
            dep=$(echo "$dep" | xargs)  # 去除空格
            
            if ! is_module_registered "$dep"; then
                errors+=("模块 '$name' 依赖的 '$dep' 未找到")
            fi
        done
    done
    
    if [[ ${#errors[@]} -gt 0 ]]; then
        for error in "${errors[@]}"; do
            log_error "$error"
        done
        error_exit "依赖验证失败"
    fi
    
    log "INFO" "依赖验证通过"
    return 0
}

################################################################################
# 配置驱动执行
################################################################################

# 根据配置文件执行模块
execute_modules_from_config() {
    local config_file="${1:-${VPC_INIT_ROOT}/config.toml}"
    
    if [[ ! -f "$config_file" ]]; then
        log "WARN" "配置文件不存在: $config_file"
        return 1
    fi
    
    log "INFO" "根据配置文件执行模块: $config_file"
    
    # 加载配置解析器
    source "${VPC_INIT_ROOT}/config.sh"
    
    if ! parse_toml "$config_file"; then
        error_exit "配置文件解析失败"
    fi
    
    # 检查哪些功能被启用
    local enabled_modules=()
    
    # 核心模块总是执行
    enabled_modules+=("user" "ssh" "system")
    
    # 根据配置启用其他模块
    if [[ "$(get_config "features:enable_firewall" "true")" == "true" ]]; then
        enabled_modules+=("firewall")
    fi
    
    if [[ "$(get_config "features:enable_nginx" "false")" == "true" ]]; then
        enabled_modules+=("nginx")
    fi
    
    if [[ "$(get_config "features:enable_docker" "false")" == "true" ]]; then
        enabled_modules+=("docker")
    fi
    
    if [[ "$(get_config "features:enable_swap" "false")" == "true" ]]; then
        enabled_modules+=("swap")
    fi
    
    if [[ "$(get_config "features:enable_security" "false")" == "true" ]]; then
        enabled_modules+=("security")
    fi
    
    if [[ "$(get_config "features:enable_p10k" "false")" == "true" ]]; then
        enabled_modules+=("p10k")
    fi
    
    # 执行启用的模块
    log "INFO" "将要执行的模块: ${enabled_modules[*]}"
    
    for module in "${enabled_modules[@]}"; do
        if is_module_registered "$module"; then
            execute_module "$module" || {
                log_error "模块执行失败: $module"
                # 询问是否继续
                if ! confirm "是否继续执行其他模块?" "Y"; then
                    return 1
                fi
            }
        else
            log "WARN" "模块未注册: $module"
        fi
    done
    
    return 0
}

################################################################################
# 交互式模块选择
################################################################################

# 交互式选择要执行的模块（一次选择多个 -> 配置 -> 执行）
select_modules_interactive() {
    print_header "交互式功能菜单"

    # 构建菜单
    local options=()
    local labels=()
    local index=1

    local categories=($(list_categories))
    for category in "${categories[@]}"; do
        options+=("__category:${category}")
        labels+=("[${category}]")

        for name in "${!MODULE_CATEGORIES[@]}"; do
            if [[ "${MODULE_CATEGORIES[$name]}" == "$category" ]]; then
                local description="${MODULE_DESCRIPTIONS[$name]}"
                options+=("${name}")
                labels+=("  ${name} - ${description}")
            fi
        done
    done

    echo "请选择要执行的功能（多个用逗号分隔，例如 1,2,3）:"
    for i in "${!options[@]}"; do
        local opt="${options[$i]}"
        if [[ "$opt" == __category:* ]]; then
            echo ""
            print_info "${labels[$i]}"
        else
            echo "  $index) ${labels[$i]}"
            index=$((index+1))
        fi
    done
    echo ""
    echo "  0) 返回/退出"
    echo ""

    read -p "请输入选择: " -r choice
    if [[ "$choice" == "0" ]]; then
        return 0
    fi
    if [[ -z "$choice" ]]; then
        print_warning "未输入任何选项"
        return 1
    fi

    # 解析选择
    local selected_modules=()
    IFS=',' read -ra CHOICES <<< "$choice"
    for item in "${CHOICES[@]}"; do
        item=$(echo "$item" | xargs)
        if [[ -z "$item" || ! "$item" =~ ^[0-9]+$ ]]; then
            print_warning "无效选项: $item"
            return 1
        fi

        if [[ "$item" == "0" ]]; then
            return 0
        fi

        local current=1
        local selected=""
        for i in "${!options[@]}"; do
            local opt="${options[$i]}"
            if [[ "$opt" == __category:* ]]; then
                continue
            fi
            if [[ $current -eq $item ]]; then
                selected="$opt"
                break
            fi
            current=$((current+1))
        done

        if [[ -z "$selected" ]]; then
            print_warning "未找到对应的功能选项: $item"
            return 1
        fi

        selected_modules+=("$selected")
    done

    if [[ ${#selected_modules[@]} -eq 0 ]]; then
        print_warning "未选择任何模块"
        return 1
    fi

    # 基于选择引导配置
    interactive_prompt_for_selected "${selected_modules[@]}"

    # 执行选择的模块（按依赖顺序）
    interactive_execute_selected "${selected_modules[@]}"

    return 0
}

interactive_set_basic() {
    print_header "基础参数设置"

    print_info "用户名格式: 字母/数字/下划线/连字符，最长 32 位"

    # 用户名
    while true; do
        read -p "请输入用户名 (默认 ${USER_NAME:-endlex}): " -r input
        if [[ -z "$input" ]]; then
            USER_NAME="${USER_NAME:-endlex}"
            break
        fi
        if validate_username "$input"; then
            USER_NAME="$input"
            break
        fi
        print_warning "用户名格式无效。示例: endlex, devops_01"
    done

    # 时区
    print_info "时区示例: Asia/Shanghai, America/New_York, Europe/London"
    while true; do
        read -p "请输入时区 (默认 ${TIMEZONE:-Asia/Shanghai}): " -r input
        if [[ -z "$input" ]]; then
            TIMEZONE="${TIMEZONE:-Asia/Shanghai}"
            break
        fi
        if validate_timezone "$input"; then
            TIMEZONE="$input"
            break
        fi
        print_warning "时区无效。请确认 /usr/share/zoneinfo/ 下存在该时区"
    done

    # SSH 公钥
    print_info "SSH 公钥格式: ssh-rsa AAAA... 或 ssh-ed25519 AAAA..."
    print_info "支持多个，用逗号分隔。也可输入公钥文件路径"
    read -p "请输入 SSH 公钥(可留空): " -r input
    if [[ -n "$input" ]]; then
        SSH_KEYS="$input"
    fi

    BASIC_CONFIGURED=true
    print_success "基础参数已更新"
}

interactive_set_nginx() {
    print_header "Nginx 参数设置"

    print_info "域名示例: example.com"
    read -p "请输入域名 (留空表示不配置): " -r input
    NGINX_DOMAIN="$input"

    if [[ -n "$NGINX_DOMAIN" ]]; then
        if confirm "是否启用 SSL?" "Y"; then
            NGINX_ENABLE_SSL=true
        else
            NGINX_ENABLE_SSL=false
        fi

        print_info "反向代理示例: http://127.0.0.1:3000"
        read -p "请输入反向代理地址 (留空表示静态站点): " -r input
        NGINX_BACKEND="$input"
    fi

    NGINX_CONFIGURED=true
    print_success "Nginx 参数已更新"
}

interactive_set_swap() {
    print_header "Swap 参数设置"

    print_info "格式示例: 1G, 2G, 512M"
    while true; do
        read -p "请输入 Swap 大小 (默认 ${SWAP_SIZE:-2G}): " -r input
        if [[ -z "$input" ]]; then
            SWAP_SIZE="${SWAP_SIZE:-2G}"
            break
        fi
        if validate_swap_size "$input"; then
            SWAP_SIZE="$input"
            break
        fi
        print_warning "Swap 格式无效。支持单位: G, M, K"
    done

    SWAP_CONFIGURED=true
    print_success "Swap 参数已更新"
}

interactive_prompt_for_selected() {
    local selected_modules=("$@")

    if has_selected_module "user" "${selected_modules[@]}" || \
       has_selected_module "ssh" "${selected_modules[@]}" || \
       has_selected_module "system" "${selected_modules[@]}"; then
        interactive_set_basic
    fi

    if has_selected_module "nginx" "${selected_modules[@]}"; then
        interactive_set_nginx
    fi

    if has_selected_module "swap" "${selected_modules[@]}"; then
        interactive_set_swap
    fi
}

has_selected_module() {
    local target="$1"
    shift
    for item in "$@"; do
        if [[ "$item" == "$target" ]]; then
            return 0
        fi
    done
    return 1
}

interactive_execute_selected() {
    local selected_modules=("$@")

    # 构建执行集合（包含依赖）
    local selected_set=()
    for module in "${selected_modules[@]}"; do
        selected_set+=("$module")

        local deps="$(get_module_depends "$module")"
        if [[ -n "$deps" ]]; then
            IFS=',' read -ra DEP_ARRAY <<< "$deps"
            for dep in "${DEP_ARRAY[@]}"; do
                dep=$(echo "$dep" | xargs)
                if [[ -n "$dep" ]]; then
                    selected_set+=("$dep")
                fi
            done
        fi
    done

    # 统一去重并按模块加载顺序执行
    local exec_set=()
    local sorted_order=($(printf '%s\n' "${MODULE_LOAD_ORDER[@]}" | sort))
    for item in "${sorted_order[@]}"; do
        local name="${item#*:}"
        for sel in "${selected_set[@]}"; do
            if [[ "$name" == "$sel" ]]; then
                exec_set+=("$name")
                break
            fi
        done
    done

    print_info "即将执行模块: ${exec_set[*]}"
    if ! confirm "确认执行?" "Y"; then
        return 0
    fi

    for module in "${exec_set[@]}"; do
        print_header "执行功能: $module"
        show_module_summary "$module"
        if ! confirm "确认执行该功能?" "Y"; then
            print_warning "已跳过: $module"
            continue
        fi

        if ! execute_module "$module"; then
            log_error "模块执行失败: $module"
            confirm "是否继续?" "Y" || return 1
        fi
    done
}

show_module_summary() {
    local module="$1"
    case "$module" in
        user)
            print_info "用户: ${USER_NAME:-endlex}"
            ;;
        system)
            print_info "时区: ${TIMEZONE:-Asia/Shanghai}"
            ;;
        ssh)
            if [[ -n "${SSH_KEYS:-}" ]]; then
                print_info "SSH 公钥: 已设置"
            else
                print_warning "SSH 公钥: 未设置"
            fi
            ;;
        firewall)
            print_info "默认开放: 22/tcp"
            if [[ "${NGINX_DOMAIN:-}" != "" ]]; then
                print_info "将开放: 80/tcp, 443/tcp"
            fi
            ;;
        nginx)
            print_info "域名: ${NGINX_DOMAIN:-未设置}"
            print_info "SSL: ${NGINX_ENABLE_SSL:-false}"
            if [[ -n "${NGINX_BACKEND:-}" ]]; then
                print_info "反向代理: ${NGINX_BACKEND}"
            else
                print_info "站点类型: 静态"
            fi
            ;;
        swap)
            print_info "Swap 大小: ${SWAP_SIZE:-2G}"
            ;;
        docker)
            print_info "安装 Docker CE + Compose"
            ;;
        security)
            print_info "安全加固: 禁用 root 登录/空密码/限制尝试/防火墙默认策略"
            ;;
        p10k)
            print_info "安装 Oh My Zsh + Powerlevel10k"
            ;;
        fix-dpkg)
            print_warning "将修复 dpkg 状态并更新包列表"
            ;;
        verify)
            print_info "执行系统环境检查"
            ;;
    esac
}

################################################################################
# 导出函数
################################################################################

if [[ -n "${BASH_VERSION:-}" ]]; then
    export -f discover_modules initialize_modules
    export -f execute_modules_from_config select_modules_interactive
fi

export MODULE_PATHS
