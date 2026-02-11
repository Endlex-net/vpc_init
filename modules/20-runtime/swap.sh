#!/bin/bash

################################################################################
# 模块: swap
# 分类: runtime
# 描述: Swap 配置
# 依赖: system
# @category: runtime
# @description: 配置 Swap 内存
# @depends: system
################################################################################

# Swap 大小
SWAP_SIZE="${SWAP_SIZE:-2G}"
SWAP_FILE="/swapfile"

# 检查函数
swap_check() {
    # 检查是否已有 swap
    if swapon --show | grep -q "swap"; then
        print_info "Swap 已存在"
        return 1
    fi
    
    if [[ -f "$SWAP_FILE" ]]; then
        print_info "Swap 文件已存在"
        return 1
    fi
    
    return 0
}

# 执行函数
swap_execute() {
    print_header "Swap 配置"
    
    print_status "创建 ${SWAP_SIZE} 的 Swap 文件..."
    
    # 创建 swap 文件
    fallocate -l "$SWAP_SIZE" "$SWAP_FILE" || {
        error_exit "创建 swap 文件失败"
    }
    
    chmod 600 "$SWAP_FILE"
    mkswap "$SWAP_FILE"
    swapon "$SWAP_FILE"
    
    # 添加到 fstab
    if ! grep -q "$SWAP_FILE" /etc/fstab; then
        echo "$SWAP_FILE none swap sw 0 0" >> /etc/fstab
    fi
    
    # 优化配置
    echo "vm.swappiness=10" >> /etc/sysctl.conf
    echo "vm.vfs_cache_pressure=50" >> /etc/sysctl.conf
    sysctl -p
    
    log "INFO" "Swap 配置完成: $SWAP_SIZE"
    print_success "Swap 配置完成"
    
    # 显示状态
    print_info "当前 Swap 状态:"
    free -h | grep -i swap
    
    return 0
}

# 注册模块
register_module \
    --name "swap" \
    --category "runtime" \
    --description "配置 Swap 虚拟内存" \
    --depends-on "system"
