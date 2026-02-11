#!/bin/bash

################################################################################
# Checkpoint Management Tool
# Purpose: Manage checkpoints for vpc_init script resumable execution
# Usage:
#   checkpoint-manager.sh list              - List all checkpoints
#   checkpoint-manager.sh reset [pattern]   - Reset specific checkpoint(s)
#   checkpoint-manager.sh clean [days]      - Clean old checkpoints
#   checkpoint-manager.sh status            - Show checkpoint status
################################################################################

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load checkpoint library
source "${SCRIPT_DIR}/checkpoint.sh" 2>/dev/null || {
    echo "Error: checkpoint.sh not found" >&2
    exit 1
}

# Checkpoint configuration
CHECKPOINT_DIR=".vpc-init-checkpoint"
export CHECKPOINT_DIR
init_checkpoint_system

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

################################################################################
# Help Function
################################################################################

show_help() {
    cat << EOF
${BLUE}╔════════════════════════════════════════════════════════════╗${NC}
${BLUE}║${NC}  ${CYAN}Checkpoint Management Tool for vpc_init${NC}
${BLUE}╚════════════════════════════════════════════════════════════╝${NC}

${YELLOW}Usage:${NC}
  checkpoint-manager.sh [COMMAND] [OPTIONS]

${YELLOW}Commands:${NC}
  ${GREEN}list${NC} [pattern]
    List all checkpoints or filter by pattern
    ${CYAN}Examples:${NC}
      checkpoint-manager.sh list
      checkpoint-manager.sh list "20260210*"

  ${GREEN}status${NC}
    Show current checkpoint status and statistics
    ${CYAN}Examples:${NC}
      checkpoint-manager.sh status

  ${GREEN}reset${NC} [pattern] [-y|--yes]
    Reset checkpoint progress (remove state files)
    Requires confirmation unless -y or --yes is provided
    ${CYAN}Examples:${NC}
      checkpoint-manager.sh reset                  # Reset all
      checkpoint-manager.sh reset "20260210*" -y   # Reset by date
      checkpoint-manager.sh reset "*" --yes        # Force reset all

  ${GREEN}clean${NC} [days]
    Remove checkpoint files older than N days (default: 7)
    ${CYAN}Examples:${NC}
      checkpoint-manager.sh clean              # Remove files older than 7 days
      checkpoint-manager.sh clean 1            # Remove files older than 1 day
      checkpoint-manager.sh clean 30           # Remove files older than 30 days

  ${GREEN}remove-date${NC} <date> [-y|--yes]
    Remove all checkpoints for a specific date (format: YYYYMMDD-HHMMSS)
    ${CYAN}Examples:${NC}
      checkpoint-manager.sh remove-date 20260210-154230
      checkpoint-manager.sh remove-date 20260210-154230 -y

  ${GREEN}keep-latest${NC} [count]
    Keep only the latest N checkpoint files (default: 5)
    ${CYAN}Examples:${NC}
      checkpoint-manager.sh keep-latest        # Keep latest 5 files
      checkpoint-manager.sh keep-latest 10     # Keep latest 10 files
      checkpoint-manager.sh keep-latest 1      # Keep only latest 1 file

  ${GREEN}help${NC}
    Show this help message

${YELLOW}Checkpoint Directory:${NC}
  ${CYAN}${CHECKPOINT_DIR}${NC}

${YELLOW}Examples:${NC}
  # List all current checkpoints
  \$ checkpoint-manager.sh list

  # Reset all checkpoints to start fresh
  \$ checkpoint-manager.sh reset -y

  # Clean old checkpoint files (older than 7 days)
  \$ checkpoint-manager.sh clean

  # Show current checkpoint statistics
  \$ checkpoint-manager.sh status

${BLUE}═══════════════════════════════════════════════════════════${NC}

EOF
}

################################################################################
# Command Handlers
################################################################################

handle_list() {
    local pattern="${1:-*}"
    
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}Checkpoint List (pattern: $pattern)${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    
    checkpoint_list "$pattern"
}

handle_status() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}Checkpoint Status${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    
    print_checkpoint_status
    
    echo ""
    echo "Recent checkpoints:"
    checkpoint_list | head -20
    
    echo ""
}

handle_reset() {
    local pattern="${1:-*}"
    local confirm="${2:-}"
    
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}Reset Checkpoints (pattern: $pattern)${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    
    checkpoint_reset "$pattern" "$confirm"
    
    echo ""
    echo -e "${GREEN}Reset complete!${NC}"
    echo ""
}

handle_clean() {
    local days="${1:-7}"
    
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}Clean Old Checkpoints (older than $days days)${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    
    checkpoint_cleanup "$days"
    
    echo ""
    echo -e "${GREEN}Cleanup complete!${NC}"
    echo ""
}

handle_remove_date() {
    local date="$1"
    local confirm="${2:-}"
    
    if [[ -z "$date" ]]; then
        echo -e "${RED}Error: Please provide date in format YYYYMMDD-HHMMSS${NC}" >&2
        return 1
    fi
    
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}Remove Checkpoints for Date: $date${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    
    checkpoint_remove_by_date "$date" "$confirm"
    
    echo ""
    echo -e "${GREEN}Removal complete!${NC}"
    echo ""
}

handle_keep_latest() {
    local count="${1:-5}"
    
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}Keep Latest Checkpoints${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    
    checkpoint_keep_latest "$count"
    
    echo ""
    echo -e "${GREEN}Cleanup complete!${NC}"
    echo ""
}

################################################################################
# Main
################################################################################

main() {
    local command="${1:-help}"
    shift || true
    
    case "$command" in
        list)
            handle_list "$@"
            ;;
        status)
            handle_status
            ;;
        reset)
            handle_reset "$@"
            ;;
        clean)
            handle_clean "$@"
            ;;
        remove-date)
            handle_remove_date "$@"
            ;;
        keep-latest)
            handle_keep_latest "$@"
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            echo -e "${RED}Error: Unknown command '$command'${NC}" >&2
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
