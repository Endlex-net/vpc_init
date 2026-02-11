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
            
            ((count++))
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

# 交互式选择要执行的模块
select_modules_interactive() {
    print_header "模块选择"
    
    local selected_modules=()
    
    # 按分类显示模块
    local categories=($(list_categories))
    
    for category in "${categories[@]}"; do
        echo ""
        print_info "[$category]"
        
        # 获取该分类的所有模块
        for name in "${!MODULE_CATEGORIES[@]}"; do
            if [[ "${MODULE_CATEGORIES[$name]}" == "$category" ]]; then
                local description="${MODULE_DESCRIPTIONS[$name]}"
                
                if confirm "是否执行 '$name' - $description?" "Y"; then
                    selected_modules+=("$name")
                fi
            fi
        done
    done
    
    echo ""
    if [[ ${#selected_modules[@]} -eq 0 ]]; then
        print_warning "未选择任何模块"
        return 1
    fi
    
    print_info "已选择模块: ${selected_modules[*]}"
    
    if confirm "确认执行这些模块?" "Y"; then
        for module in "${selected_modules[@]}"; do
            execute_module "$module" || {
                log_error "模块执行失败: $module"
                if ! confirm "是否继续?" "Y"; then
                    return 1
                fi
            }
        done
    fi
    
    return 0
}

################################################################################
# 导出函数
################################################################################

if [[ -n "${BASH_VERSION:-}" ]]; then
    export -f discover_modules initialize_modules
    export -f execute_modules_from_config select_modules_interactive
fi

export MODULE_PATHS
