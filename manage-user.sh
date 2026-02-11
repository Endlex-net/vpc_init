#!/bin/bash

################################################################################
# SSH Key Management Script
# Purpose: Add SSH public keys to user account after initialization
################################################################################

set -euo pipefail

USERNAME="endlex"
SSH_DIR="/home/${USERNAME}/.ssh"
AUTHORIZED_KEYS_FILE="${SSH_DIR}/authorized_keys"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}Error: This script must be run as root${NC}" >&2
    exit 1
fi

# Function to add SSH key
add_ssh_key() {
    local key_file="$1"
    
    if [[ ! -f "${key_file}" ]]; then
        echo -e "${RED}Error: Key file '${key_file}' not found${NC}" >&2
        return 1
    fi
    
    local public_key=$(cat "${key_file}")
    
    # Validate SSH key format
    if ! echo "${public_key}" | grep -qE '^(ssh-rsa|ssh-dss|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521|ssh-ed25519)'; then
        echo -e "${RED}Error: Invalid SSH key format${NC}" >&2
        return 1
    fi
    
    # Ensure authorized_keys exists
    if [[ ! -f "${AUTHORIZED_KEYS_FILE}" ]]; then
        mkdir -p "${SSH_DIR}"
        touch "${AUTHORIZED_KEYS_FILE}"
        chown "${USERNAME}:${USERNAME}" "${SSH_DIR}" "${AUTHORIZED_KEYS_FILE}"
        chmod 700 "${SSH_DIR}"
        chmod 600 "${AUTHORIZED_KEYS_FILE}"
    fi
    
    # Check if key already exists
    if grep -q "$(echo "${public_key}" | awk '{print $1, $2}')" "${AUTHORIZED_KEYS_FILE}" 2>/dev/null; then
        echo -e "${YELLOW}Warning: SSH key already exists${NC}"
        return 0
    fi
    
    # Add key
    echo "${public_key}" >> "${AUTHORIZED_KEYS_FILE}"
    chown "${USERNAME}:${USERNAME}" "${AUTHORIZED_KEYS_FILE}"
    
    echo -e "${GREEN}✓ SSH key added successfully${NC}"
}

# Function to list SSH keys
list_ssh_keys() {
    if [[ ! -f "${AUTHORIZED_KEYS_FILE}" ]]; then
        echo -e "${YELLOW}No SSH keys configured${NC}"
        return
    fi
    
    echo "SSH keys for ${USERNAME}:"
    echo "───────────────────────────"
    nl -v 1 "${AUTHORIZED_KEYS_FILE}" | sed 's/^[[:space:]]*//'
}

# Function to remove SSH key
remove_ssh_key() {
    local key_number="$1"
    
    if [[ ! -f "${AUTHORIZED_KEYS_FILE}" ]]; then
        echo -e "${RED}No SSH keys found${NC}" >&2
        return 1
    fi
    
    local total_keys=$(wc -l < "${AUTHORIZED_KEYS_FILE}")
    
    if [[ ${key_number} -lt 1 ]] || [[ ${key_number} -gt ${total_keys} ]]; then
        echo -e "${RED}Invalid key number (1-${total_keys})${NC}" >&2
        return 1
    fi
    
    sed -i.bak "${key_number}d" "${AUTHORIZED_KEYS_FILE}"
    rm -f "${AUTHORIZED_KEYS_FILE}.bak"
    
    echo -e "${GREEN}✓ SSH key removed${NC}"
}

# Function to reset password
reset_password() {
    local password=$1
    
    if [[ -z "${password}" ]]; then
        password=$(openssl rand -base64 32 | sed 's/[^a-zA-Z0-9]//g' | cut -c1-24)
        echo "Generated password: ${password}"
    fi
    
    echo "${USERNAME}:${password}" | chpasswd
    echo -e "${GREEN}✓ Password reset successfully${NC}"
}

# Show usage
show_usage() {
    cat << EOF
Usage: $(basename "$0") [COMMAND] [OPTIONS]

Commands:
  add <key-file>        Add SSH public key from file
  list                  List all SSH keys
  remove <number>       Remove SSH key by number
  password [password]   Reset user password (generates random if not provided)
  help                  Show this help message

Examples:
  $(basename "$0") add ~/.ssh/id_rsa.pub
  $(basename "$0") list
  $(basename "$0") remove 1
  $(basename "$0") password NewPassword123!
  $(basename "$0") password  # Generate random password

EOF
}

# Main
case "${1:-help}" in
    add)
        if [[ $# -lt 2 ]]; then
            echo -e "${RED}Error: Key file required${NC}" >&2
            echo "Usage: $(basename "$0") add <key-file>"
            exit 1
        fi
        add_ssh_key "$2"
        ;;
    list)
        list_ssh_keys
        ;;
    remove)
        if [[ $# -lt 2 ]]; then
            echo -e "${RED}Error: Key number required${NC}" >&2
            echo "Usage: $(basename "$0") remove <number>"
            exit 1
        fi
        remove_ssh_key "$2"
        ;;
    password)
        reset_password "${2:-}"
        ;;
    help|--help|-h)
        show_usage
        ;;
    *)
        echo -e "${RED}Unknown command: $1${NC}" >&2
        show_usage
        exit 1
        ;;
esac
