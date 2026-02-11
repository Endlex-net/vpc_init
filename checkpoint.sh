#!/bin/bash

################################################################################
# Checkpoint & Resume Library for vpc_init
# Purpose: Provide checkpoint management for resumable script execution
# Features:
#   - Save checkpoint state to temporary file
#   - Check if checkpoint is already completed
#   - List all completed checkpoints
#   - Reset/clear checkpoint states
#   - Automatic cleanup on completion
################################################################################

set -euo pipefail

# Checkpoint storage directory
CHECKPOINT_DIR="${CHECKPOINT_DIR:-.checkpoint}"
CHECKPOINT_PREFIX="init"
CHECKPOINT_FILE="${CHECKPOINT_DIR}/${CHECKPOINT_PREFIX}-state-$(date +%s).tmp"

# State file for current session (created when first checkpoint is made)
CURRENT_STATE_FILE=""

################################################################################
# Core Checkpoint Functions
################################################################################

# Initialize checkpoint system
init_checkpoint_system() {
    mkdir -p "${CHECKPOINT_DIR}" 2>/dev/null || true
    
    # Clean up old checkpoint files (older than 1 day)
    find "${CHECKPOINT_DIR}" -name "${CHECKPOINT_PREFIX}-state-*.tmp" -mtime +1 -delete 2>/dev/null || true
}

# Create a checkpoint and record successful completion
checkpoint_mark() {
    local checkpoint_name="$1"
    local description="${2:-}"
    
    # Create state file if not exists
    if [[ -z "$CURRENT_STATE_FILE" ]]; then
        CURRENT_STATE_FILE="${CHECKPOINT_DIR}/${CHECKPOINT_PREFIX}-$(date +%Y%m%d-%H%M%S).state"
        > "$CURRENT_STATE_FILE"  # Create empty file
    fi
    
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Record checkpoint with format: checkpoint_name|timestamp|description|status
    echo "${checkpoint_name}|${timestamp}|${description}|COMPLETED" >> "$CURRENT_STATE_FILE"
    
    return 0
}

# Check if a checkpoint was already completed
checkpoint_exists() {
    local checkpoint_name="$1"
    
    # Check if any state file contains this checkpoint as COMPLETED
    for state_file in "${CHECKPOINT_DIR}"/${CHECKPOINT_PREFIX}-*.state; do
        if [[ -f "$state_file" ]]; then
            if grep -q "^${checkpoint_name}|.*|COMPLETED$" "$state_file" 2>/dev/null; then
                return 0  # Checkpoint exists and is completed
            fi
        fi
    done
    
    return 1  # Checkpoint not found or not completed
}

# Execute function only if checkpoint was not completed before
checkpoint_execute() {
    local checkpoint_name="$1"
    shift
    local func_name="$1"
    shift
    local args=("$@")
    
    if checkpoint_exists "$checkpoint_name"; then
        print_checkpoint_skipped "$checkpoint_name"
        return 0
    fi
    
    # Execute the function with remaining arguments
    "$func_name" "${args[@]}"
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        checkpoint_mark "$checkpoint_name"
    fi
    
    return $exit_code
}

# Skip checkpoint (mark as completed without executing)
checkpoint_skip() {
    local checkpoint_name="$1"
    local reason="${2:-User skipped}"
    
    checkpoint_mark "$checkpoint_name" "$reason"
    return 0
}

################################################################################
# Checkpoint Query Functions
################################################################################

# List all completed checkpoints
checkpoint_list() {
    local pattern="${1:-*}"
    
    if ! ls "${CHECKPOINT_DIR}"/${CHECKPOINT_PREFIX}-${pattern}.state 1>/dev/null 2>&1; then
        echo "No checkpoint files found matching: ${pattern}"
        return 1
    fi
    
    for state_file in "${CHECKPOINT_DIR}"/${CHECKPOINT_PREFIX}-${pattern}.state; do
        if [[ -f "$state_file" ]]; then
            echo ""
            echo "═══════════════════════════════════════════════════════"
            echo "State file: $(basename "$state_file")"
            echo "═══════════════════════════════════════════════════════"
            
            if [[ -s "$state_file" ]]; then
                awk -F'|' '{
                    printf "  %-30s %s  %s\n", $1, $2, (NF > 3 ? $4 : "")
                }' "$state_file"
            else
                echo "  (empty)"
            fi
            echo ""
        fi
    done
}

# Get checkpoint count
checkpoint_count() {
    local pattern="${1:-*}"
    local count=0
    
    for state_file in "${CHECKPOINT_DIR}"/${CHECKPOINT_PREFIX}-${pattern}.state; do
        if [[ -f "$state_file" ]]; then
            count=$(( count + $(grep -c "COMPLETED$" "$state_file" 2>/dev/null || echo 0) ))
        fi
    done
    
    echo "$count"
}

# Get latest checkpoint state file
checkpoint_get_latest() {
    local latest_file=""
    local latest_mtime=0
    
    for state_file in "${CHECKPOINT_DIR}"/${CHECKPOINT_PREFIX}-*.state; do
        if [[ -f "$state_file" ]]; then
            local mtime=$(stat -f%m "$state_file" 2>/dev/null || stat -c%Y "$state_file" 2>/dev/null || echo 0)
            if [[ $mtime -gt $latest_mtime ]]; then
                latest_mtime=$mtime
                latest_file="$state_file"
            fi
        fi
    done
    
    if [[ -n "$latest_file" ]]; then
        echo "$latest_file"
        return 0
    fi
    
    return 1
}

################################################################################
# Checkpoint Management Functions
################################################################################

# Reset checkpoint progress (remove state file)
checkpoint_reset() {
    local pattern="${1:-*}"
    local confirmation="${2:-}"
    
    local files_to_delete=()
    for state_file in "${CHECKPOINT_DIR}"/${CHECKPOINT_PREFIX}-${pattern}.state; do
        if [[ -f "$state_file" ]]; then
            files_to_delete+=("$state_file")
        fi
    done
    
    if [[ ${#files_to_delete[@]} -eq 0 ]]; then
        echo "No checkpoint files found to reset"
        return 1
    fi
    
    # Ask for confirmation if not provided
    if [[ "$confirmation" != "-y" && "$confirmation" != "--yes" ]]; then
        echo "Checkpoints to be reset:"
        printf '  %s\n' "${files_to_delete[@]}"
        read -p "Continue? [y/N] " -n 1 -r confirm
        echo
        if [[ ! $confirm =~ ^[Yy]$ ]]; then
            echo "Reset cancelled"
            return 1
        fi
    fi
    
    # Delete checkpoint files
    for file in "${files_to_delete[@]}"; do
        rm -f "$file"
        echo "Removed: $file"
    done
    
    return 0
}

# Clear all checkpoints older than N days
checkpoint_cleanup() {
    local days="${1:-7}"
    
    local count=0
    while IFS= read -r file; do
        rm -f "$file"
        ((count++))
        echo "Cleaned: $file"
    done < <(find "${CHECKPOINT_DIR}" -name "${CHECKPOINT_PREFIX}-*.state" -mtime +"$days" 2>/dev/null)
    
    if [[ $count -gt 0 ]]; then
        echo "Cleaned $count checkpoint files older than $days days"
    else
        echo "No checkpoint files to clean"
    fi
    
    return 0
}

# Remove all checkpoint data for a specific date
checkpoint_remove_by_date() {
    local date="$1"  # Format: YYYYMMDD-HHMMSS
    local confirmation="${2:-}"
    
    local pattern="${date}"
    
    local files_to_delete=()
    for state_file in "${CHECKPOINT_DIR}"/${CHECKPOINT_PREFIX}-${pattern}.state; do
        if [[ -f "$state_file" ]]; then
            files_to_delete+=("$state_file")
        fi
    done
    
    if [[ ${#files_to_delete[@]} -eq 0 ]]; then
        echo "No checkpoint files found for date: $date"
        return 1
    fi
    
    echo "Files to remove:"
    printf '  %s\n' "${files_to_delete[@]}"
    
    if [[ "$confirmation" != "-y" && "$confirmation" != "--yes" ]]; then
        read -p "Continue? [y/N] " -n 1 -r confirm
        echo
        if [[ ! $confirm =~ ^[Yy]$ ]]; then
            echo "Removal cancelled"
            return 1
        fi
    fi
    
    for file in "${files_to_delete[@]}"; do
        rm -f "$file"
        echo "Removed: $file"
    done
    
    return 0
}

# Keep only the latest N checkpoint files
checkpoint_keep_latest() {
    local keep_count="${1:-5}"
    
    local all_files=($(ls -t "${CHECKPOINT_DIR}"/${CHECKPOINT_PREFIX}-*.state 2>/dev/null || true))
    
    if [[ ${#all_files[@]} -le $keep_count ]]; then
        echo "Current checkpoint files: ${#all_files[@]} (keeping all)"
        return 0
    fi
    
    echo "Keeping latest $keep_count checkpoint files..."
    
    for ((i = keep_count; i < ${#all_files[@]}; i++)); do
        rm -f "${all_files[$i]}"
        echo "Removed: ${all_files[$i]}"
    done
    
    echo "Cleanup complete. Files kept: $keep_count"
    return 0
}

################################################################################
# Output Helper Functions
################################################################################

# Print checkpoint skipped message
print_checkpoint_skipped() {
    local checkpoint_name="$1"
    local color_yellow='\033[1;33m'
    local color_nc='\033[0m'
    
    echo -e "${color_yellow}⊘${color_nc} [SKIPPED] Checkpoint '${checkpoint_name}' already completed"
}

# Print checkpoint marked message
print_checkpoint_marked() {
    local checkpoint_name="$1"
    local color_green='\033[0;32m'
    local color_nc='\033[0m'
    
    echo -e "${color_green}✓${color_nc} [CHECKPOINT] Marked '${checkpoint_name}' as completed"
}

# Print checkpoint status
print_checkpoint_status() {
    local total_files=0
    local total_checkpoints=0
    
    for state_file in "${CHECKPOINT_DIR}"/${CHECKPOINT_PREFIX}-*.state; do
        if [[ -f "$state_file" ]]; then
            ((total_files++))
            total_checkpoints=$(( total_checkpoints + $(grep -c "COMPLETED$" "$state_file" 2>/dev/null || echo 0) ))
        fi
    done
    
    echo "Checkpoint Status:"
    echo "  • State files: $total_files"
    echo "  • Total checkpoints: $total_checkpoints"
    echo "  • Storage directory: ${CHECKPOINT_DIR}"
}

################################################################################
# Export for use in other scripts
################################################################################

# Export functions for use in other scripts
export -f init_checkpoint_system
export -f checkpoint_mark
export -f checkpoint_exists
export -f checkpoint_execute
export -f checkpoint_skip
export -f checkpoint_list
export -f checkpoint_count
export -f checkpoint_get_latest
export -f checkpoint_reset
export -f checkpoint_cleanup
export -f checkpoint_remove_by_date
export -f checkpoint_keep_latest
export -f print_checkpoint_skipped
export -f print_checkpoint_marked
export -f print_checkpoint_status
