#!/bin/bash

################################################################################
# VPC_INIT 断点续跑系统
# 整合自 checkpoint.sh
################################################################################

# 断点目录 - 延迟初始化，在 init_checkpoint 中设置
CHECKPOINT_DIR=""
CURRENT_STATE_FILE=""

################################################################################
# 断点管理
################################################################################

# 初始化断点系统
init_checkpoint() {
    # 如果 CHECKPOINT_DIR 未设置，使用默认值
    if [[ -z "${CHECKPOINT_DIR:-}" ]]; then
        CHECKPOINT_DIR="${VPC_INIT_ROOT}/.checkpoint"
    fi
    
    # 创建目录
    if ! mkdir -p "${CHECKPOINT_DIR}" 2>/dev/null; then
        log "ERROR" "无法创建检查点目录: $CHECKPOINT_DIR"
        return 1
    fi
    
    # 验证目录创建成功
    if [[ ! -d "${CHECKPOINT_DIR}" ]]; then
        log "ERROR" "检查点目录创建失败: $CHECKPOINT_DIR"
        return 1
    fi
    
    # 清理旧断点（7天前）
    find "${CHECKPOINT_DIR}" -maxdepth 1 -name "*.state" -mtime +7 -delete 2>/dev/null || true
    
    log "DEBUG" "断点系统初始化完成: $CHECKPOINT_DIR"
}

# 标记断点完成
mark_checkpoint() {
    local name="$1"
    local desc="${2:-}"
    
    # 创建状态文件
    if [[ -z "$CURRENT_STATE_FILE" ]]; then
        CURRENT_STATE_FILE="${CHECKPOINT_DIR}/vpc-init-$(date +%Y%m%d-%H%M%S).state"
        > "$CURRENT_STATE_FILE"
    fi
    
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "${name}|${timestamp}|${desc}|COMPLETED" >> "$CURRENT_STATE_FILE"
    
    log "DEBUG" "断点完成: $name"
}

# 检查断点是否已完成
is_checkpoint_done() {
    local name="$1"
    
    if [[ -z "$CURRENT_STATE_FILE" ]]; then
        # 查找最新的状态文件
        CURRENT_STATE_FILE=$(find "${CHECKPOINT_DIR}" -name "*.state" -type f -print0 2>/dev/null | \
            xargs -0 ls -t 2>/dev/null | head -1)
    fi
    
    if [[ -n "$CURRENT_STATE_FILE" && -f "$CURRENT_STATE_FILE" ]]; then
        grep -q "^${name}|" "$CURRENT_STATE_FILE" 2>/dev/null
        return $?
    fi
    
    return 1
}

# 检查并从断点恢复
check_resume() {
    # 确保检查点目录存在
    if [[ ! -d "${CHECKPOINT_DIR}" ]]; then
        log "DEBUG" "检查点目录不存在，跳过恢复检查"
        return 1
    fi
    
    # 查找最新的状态文件
    local latest_state=$(find "${CHECKPOINT_DIR}" -maxdepth 1 -name "*.state" -type f -print0 2>/dev/null | \
        xargs -0 ls -t 2>/dev/null | head -1)
    
    # 验证找到的文件
    if [[ -z "$latest_state" ]] || [[ ! -f "$latest_state" ]]; then
        log "DEBUG" "没有找到有效的状态文件"
        return 1
    fi
    
    # 确保文件在正确的目录中
    if [[ "$(dirname "$latest_state")" != "$CHECKPOINT_DIR" ]]; then
        log "WARN" "状态文件路径异常: $latest_state"
        return 1
    fi
    
    echo ""
    print_warning "发现之前的执行状态"
    print_info "状态文件: $(basename $latest_state)"
    echo ""
    
    # 显示已完成的步骤
    print_info "已完成的步骤:"
    grep "COMPLETED" "$latest_state" 2>/dev/null | while IFS='|' read -r name timestamp desc status; do
        echo "  ✓ $name"
    done
    echo ""
    
    if confirm "是否从断点继续执行?" "Y"; then
        CURRENT_STATE_FILE="$latest_state"
        log "INFO" "从断点恢复: $latest_state"
        return 0
    else
        # 创建新的状态文件
        CURRENT_STATE_FILE=""
        log "INFO" "开始新的执行"
        return 1
    fi
}

# 执行模块（带断点）
execute_module_with_checkpoint() {
    local module="$1"
    
    # 检查是否已完成
    if is_checkpoint_done "$module"; then
        print_info "模块已完成，跳过: $module"
        return 0
    fi
    
    # 执行模块
    if execute_module "$module"; then
        mark_checkpoint "$module"
        return 0
    else
        return 1
    fi
}

# 列出所有断点
list_checkpoints() {
    print_header "断点列表"
    
    local states=($(find "${CHECKPOINT_DIR}" -name "*.state" -type f 2>/dev/null | sort -r))
    
    if [[ ${#states[@]} -eq 0 ]]; then
        print_info "没有找到断点记录"
        return 0
    fi
    
    for state in "${states[@]}"; do
        echo ""
        print_info "文件: $(basename $state)"
        echo "  完成步骤:"
        grep "COMPLETED" "$state" 2>/dev/null | while IFS='|' read -r name timestamp desc status; do
            echo "    - $name ($timestamp)"
        done
    done
}

# 清除断点
clear_checkpoints() {
    if confirm "确定要清除所有断点记录?" "N"; then
        rm -rf "${CHECKPOINT_DIR}"/*
        print_success "断点记录已清除"
        log "INFO" "断点记录已清除"
    fi
}

################################################################################
# 导出函数
################################################################################

if [[ -n "${BASH_VERSION:-}" ]]; then
    export -f init_checkpoint mark_checkpoint is_checkpoint_done
    export -f check_resume execute_module_with_checkpoint
    export -f list_checkpoints clear_checkpoints
fi
