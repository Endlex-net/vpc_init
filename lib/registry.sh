#!/bin/bash

################################################################################
# VPC_INIT 模块注册表
# 管理所有可用模块，提供注册、查询、加载功能
################################################################################

# 模块注册表（关联数组）
declare -A MODULE_REGISTRY
declare -A MODULE_CATEGORIES
declare -A MODULE_DESCRIPTIONS
declare -A MODULE_DEPENDS
declare -A MODULE_CONFIG_SECTIONS
declare -A MODULE_FILES

# 模块加载顺序（数组）
declare -a MODULE_LOAD_ORDER

################################################################################
# 模块注册
################################################################################

# 注册新模块
# 使用方式：
#   register_module \
#       --name "nginx" \
#       --category "network" \
#       --description "安装并配置 Nginx" \
#       --depends-on "system" \
#       --config-section "nginx" \
#       --file "modules/10-network/nginx.sh"
#
# 或使用简单方式：
#   register_module --name "user" --category "core" --description "用户管理"
register_module() {
    local name=""
    local category=""
    local description=""
    local depends_on=""
    local config_section=""
    local file=""
    
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --name)
                name="$2"
                shift 2
                ;;
            --category)
                category="$2"
                shift 2
                ;;
            --description)
                description="$2"
                shift 2
                ;;
            --depends-on)
                depends_on="$2"
                shift 2
                ;;
            --config-section)
                config_section="$2"
                shift 2
                ;;
            --file)
                file="$2"
                shift 2
                ;;
            *)
                shift
                ;;
        esac
    done
    
    # 验证必要参数
    if [[ -z "$name" ]]; then
        echo "错误: 模块名称不能为空" >&2
        return 1
    fi
    
    # 如果未指定文件，自动推断
    if [[ -z "$file" ]]; then
        file=$(find_module_file "$name")
        if [[ -z "$file" ]]; then
            echo "错误: 无法找到模块 '$name' 的文件" >&2
            return 1
        fi
    fi
    
    # 注册模块
    MODULE_REGISTRY["$name"]="registered"
    MODULE_CATEGORIES["$name"]="${category:-other}"
    MODULE_DESCRIPTIONS["$name"]="${description:-$name 模块}"
    MODULE_DEPENDS["$name"]="${depends_on:-}"
    MODULE_CONFIG_SECTIONS["$name"]="${config_section:-}"
    MODULE_FILES["$name"]="$file"
    
    # 添加到加载顺序（根据分类排序）
    local order=$(get_category_order "$category")
    MODULE_LOAD_ORDER+=("$order:$name")
    
    log "DEBUG" "模块已注册: $name (分类: ${category:-other})"
    return 0
}

# 获取分类排序权重
get_category_order() {
    local category="${1:-other}"
    case "$category" in
        core)     echo "10" ;;
        system)   echo "20" ;;
        network)  echo "30" ;;
        runtime)  echo "40" ;;
        tools)    echo "50" ;;
        *)        echo "99" ;;
    esac
}

# 查找模块文件
find_module_file() {
    local name="$1"
    local module_dirs=("${VPC_INIT_ROOT}/modules/00-core" "${VPC_INIT_ROOT}/modules/10-network" "${VPC_INIT_ROOT}/modules/20-runtime" "${VPC_INIT_ROOT}/modules/30-tools")
    
    for dir in "${module_dirs[@]}"; do
        if [[ -f "${dir}/${name}.sh" ]]; then
            echo "${dir}/${name}.sh"
            return 0
        fi
    done
    
    return 1
}

################################################################################
# 模块查询
################################################################################

# 检查模块是否已注册
is_module_registered() {
    local name="$1"
    [[ -n "${MODULE_REGISTRY[$name]:-}" ]]
}

# 获取模块分类
get_module_category() {
    local name="$1"
    echo "${MODULE_CATEGORIES[$name]:-other}"
}

# 获取模块描述
get_module_description() {
    local name="$1"
    echo "${MODULE_DESCRIPTIONS[$name]:-$name}"
}

# 获取模块依赖
get_module_depends() {
    local name="$1"
    echo "${MODULE_DEPENDS[$name]:-}"
}

# 获取模块配置段
get_module_config_section() {
    local name="$1"
    echo "${MODULE_CONFIG_SECTIONS[$name]:-}"
}

# 获取模块文件路径
get_module_file() {
    local name="$1"
    echo "${MODULE_FILES[$name]:-}"
}

# 列出所有模块
list_modules() {
    local category_filter="${1:-}"
    
    log "INFO" "已注册模块列表:"
    
    # 按分类排序
    local sorted_order=($(printf '%s\n' "${MODULE_LOAD_ORDER[@]}" | sort))
    
    local current_category=""
    for item in "${sorted_order[@]}"; do
        local name="${item#*:}"
        local category="${MODULE_CATEGORIES[$name]}"
        
        # 过滤分类
        if [[ -n "$category_filter" && "$category" != "$category_filter" ]]; then
            continue
        fi
        
        # 显示分类标题
        if [[ "$category" != "$current_category" ]]; then
            echo ""
            print_info "[$category]"
            current_category="$category"
        fi
        
        # 显示模块信息
        local description="${MODULE_DESCRIPTIONS[$name]}"
        local depends="${MODULE_DEPENDS[$name]}"
        
        if [[ -n "$depends" ]]; then
            printf "  %-20s %s (依赖: %s)\n" "$name" "$description" "$depends"
        else
            printf "  %-20s %s\n" "$name" "$description"
        fi
    done
}

# 列出所有分类
list_categories() {
    local categories=()
    
    for name in "${!MODULE_CATEGORIES[@]}"; do
        local cat="${MODULE_CATEGORIES[$name]}"
        if [[ ! " ${categories[@]} " =~ " ${cat} " ]]; then
            categories+=("$cat")
        fi
    done
    
    printf '%s\n' "${categories[@]}" | sort
}

################################################################################
# 模块加载
################################################################################

# 加载模块
load_module() {
    local name="$1"
    
    if ! is_module_registered "$name"; then
        log_error "模块未注册: $name"
        return 1
    fi
    
    local file="${MODULE_FILES[$name]}"
    
    if [[ ! -f "$file" ]]; then
        log_error "模块文件不存在: $file"
        return 1
    fi
    
    log "INFO" "加载模块: $name ($file)"
    source "$file"
    
    return 0
}

# 加载所有模块
load_all_modules() {
    log "INFO" "开始加载所有模块..."
    
    local sorted_order=($(printf '%s\n' "${MODULE_LOAD_ORDER[@]}" | sort))
    
    for item in "${sorted_order[@]}"; do
        local name="${item#*:}"
        load_module "$name" || {
            log_error "加载模块失败: $name"
            return 1
        }
    done
    
    print_success "所有模块加载完成"
    return 0
}

# 按分类加载模块
load_modules_by_category() {
    local category="$1"
    
    log "INFO" "加载分类 '$category' 的模块..."
    
    local count=0
    for name in "${!MODULE_CATEGORIES[@]}"; do
        if [[ "${MODULE_CATEGORIES[$name]}" == "$category" ]]; then
            load_module "$name" || return 1
            ((count++))
        fi
    done
    
    log "INFO" "已加载 $count 个模块"
    return 0
}

################################################################################
# 模块执行
################################################################################

# 执行模块（如果存在 execute 函数）
execute_module() {
    local name="$1"
    shift
    
    if ! is_module_registered "$name"; then
        log_error "模块未注册: $name"
        return 1
    fi
    
    # 检查模块是否已加载
    local func_name="${name}_execute"
    if ! declare -f "$func_name" &>/dev/null; then
        load_module "$name" || return 1
    fi
    
    # 执行模块
    log "INFO" "执行模块: $name"
    $func_name "$@"
    
    return $?
}

# 执行所有模块
execute_all_modules() {
    log "INFO" "开始执行所有模块..."
    
    local sorted_order=($(printf '%s\n' "${MODULE_LOAD_ORDER[@]}" | sort))
    local failed=()
    
    for item in "${sorted_order[@]}"; do
        local name="${item#*:}"
        
        if declare -f "${name}_check" &>/dev/null; then
            # 先检查
            if ! ${name}_check; then
                log "INFO" "模块 $name 检查未通过，跳过"
                continue
            fi
        fi
        
        # 执行
        if execute_module "$name"; then
            print_success "模块执行成功: $name"
        else
            log_error "模块执行失败: $name"
            failed+=("$name")
        fi
    done
    
    if [[ ${#failed[@]} -gt 0 ]]; then
        log_error "以下模块执行失败: ${failed[*]}"
        return 1
    fi
    
    print_success "所有模块执行完成"
    return 0
}

################################################################################
# 导出函数
################################################################################

if [[ -n "${BASH_VERSION:-}" ]]; then
    export -f register_module is_module_registered
    export -f get_module_category get_module_description get_module_depends
    export -f get_module_config_section get_module_file
    export -f list_modules list_categories
    export -f load_module load_all_modules load_modules_by_category
    export -f execute_module execute_all_modules
fi
