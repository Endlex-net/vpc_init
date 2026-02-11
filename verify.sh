#!/bin/bash

################################################################################
# Verification and Health Check Script
# Purpose: Verify that initialization was successful
################################################################################

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

USERNAME="endlex"
CHECKS_PASSED=0
CHECKS_FAILED=0
CHECKS_TOTAL=0

# Helper functions
check_status() {
    local check_name="$1"
    local result="$2"
    
    ((CHECKS_TOTAL++))
    
    if [[ "$result" == "pass" ]]; then
        echo -e "${GREEN}✓${NC} $check_name"
        ((CHECKS_PASSED++))
    else
        echo -e "${RED}✗${NC} $check_name"
        ((CHECKS_FAILED++))
    fi
}

print_header() {
    echo -e "\n${BLUE}══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}══════════════════════════════════════════════════════════${NC}\n"
}

# Check user exists
check_user_exists() {
    print_header "User Account Checks"
    
    if id "$USERNAME" &>/dev/null; then
        check_status "User '$USERNAME' exists" "pass"
    else
        check_status "User '$USERNAME' exists" "fail"
    fi
}

# Check home directory
check_home_directory() {
    local home_dir="/home/$USERNAME"
    
    if [[ -d "$home_dir" ]]; then
        check_status "Home directory exists" "pass"
    else
        check_status "Home directory exists" "fail"
    fi
    
    if [[ -O "$home_dir" ]]; then
        check_status "Home directory ownership correct" "pass"
    else
        check_status "Home directory ownership correct" "fail"
    fi
}

# Check sudo privileges
check_sudo() {
    print_header "Sudo Access Checks"
    
    if sudo -l -U "$USERNAME" &>/dev/null 2>&1 || grep -q "^$USERNAME" /etc/sudoers.d/* 2>/dev/null; then
        check_status "Sudo privileges configured" "pass"
    else
        check_status "Sudo privileges configured" "fail"
    fi
}

# Check SSH configuration
check_ssh() {
    print_header "SSH Configuration Checks"
    
    local ssh_dir="/home/$USERNAME/.ssh"
    
    if [[ -d "$ssh_dir" ]]; then
        check_status "SSH directory exists" "pass"
    else
        check_status "SSH directory exists" "fail"
        return
    fi
    
    if [[ -f "$ssh_dir/authorized_keys" ]]; then
        check_status "authorized_keys file exists" "pass"
    else
        check_status "authorized_keys file exists" "fail"
    fi
    
    # Check permissions
    local ssh_perms=$(ls -ld "$ssh_dir" | awk '{print substr($1, 2, 3)}')
    if [[ "$ssh_perms" == "700" ]]; then
        check_status "SSH directory permissions (700)" "pass"
    else
        check_status "SSH directory permissions (700)" "fail"
    fi
}

# Check SSH keys
check_ssh_keys() {
    local auth_keys="/home/$USERNAME/.ssh/authorized_keys"
    
    if [[ ! -f "$auth_keys" ]]; then
        echo -e "${YELLOW}  No authorized_keys file${NC}"
        return
    fi
    
    local key_count=$(wc -l < "$auth_keys" | xargs)
    
    if [[ $key_count -gt 0 ]]; then
        check_status "SSH keys configured ($key_count key(s))" "pass"
        echo ""
        echo "  SSH Keys:"
        nl -v 1 "$auth_keys" | sed 's/^/    /'
    else
        echo -e "${YELLOW}  No SSH keys configured yet${NC}"
    fi
}

# Check system packages
check_packages() {
    print_header "System Package Checks"
    
    local packages=("curl" "wget" "git" "ssh")
    
    for pkg in "${packages[@]}"; do
        if dpkg -l | grep -q "^ii.*$pkg"; then
            check_status "Package '$pkg' installed" "pass"
        else
            check_status "Package '$pkg' installed" "fail"
        fi
    done
}

# Check SSH service
check_ssh_service() {
    print_header "SSH Service Checks"
    
    if systemctl is-active --quiet ssh 2>/dev/null; then
        check_status "SSH service is running" "pass"
    elif systemctl is-active --quiet sshd 2>/dev/null; then
        check_status "SSH service is running" "pass"
    else
        check_status "SSH service is running" "fail"
    fi
    
    if systemctl is-enabled ssh 2>/dev/null || systemctl is-enabled sshd 2>/dev/null; then
        check_status "SSH service is enabled" "pass"
    else
        check_status "SSH service is enabled" "fail"
    fi
}

# Check firewall
check_firewall() {
    print_header "Firewall Checks"
    
    if command -v ufw &>/dev/null; then
        if ufw status | grep -q "Status: active"; then
            check_status "Firewall (UFW) is active" "pass"
            
            if ufw status | grep -q "22/tcp"; then
                check_status "SSH port is allowed" "pass"
            else
                check_status "SSH port is allowed" "fail"
            fi
        else
            check_status "Firewall (UFW) is active" "fail"
        fi
    else
        echo -e "${YELLOW}  UFW not installed${NC}"
    fi
}

# Check credentials file
check_credentials() {
    print_header "Credentials File Checks"
    
    local creds_file="/root/${USERNAME}-credentials.txt"
    
    if [[ -f "$creds_file" ]]; then
        check_status "Credentials file exists" "pass"
        
        if [[ -r "$creds_file" ]]; then
            check_status "Credentials file is readable" "pass"
        else
            check_status "Credentials file is readable" "fail"
        fi
    else
        echo -e "${YELLOW}  Credentials file not found (may have been removed)${NC}"
    fi
}

# Check logs
check_logs() {
    print_header "Log File Checks"
    
    local log_dir="/var/log/vpc-init"
    
    if [[ -d "$log_dir" ]]; then
        check_status "Log directory exists" "pass"
        
        local log_count=$(ls -1 "$log_dir" 2>/dev/null | wc -l)
        if [[ $log_count -gt 0 ]]; then
            check_status "Log files exist ($log_count file(s))" "pass"
        else
            check_status "Log files exist" "fail"
        fi
    else
        echo -e "${YELLOW}  No log directory found${NC}"
    fi
}

# Check system info
check_system_info() {
    print_header "System Information"
    
    echo "Hostname: $(hostname)"
    echo "Kernel: $(uname -r)"
    
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        echo "OS: $PRETTY_NAME"
    fi
    
    echo "Uptime: $(uptime -p 2>/dev/null || uptime)"
    echo ""
}

# Print summary
print_summary() {
    print_header "Verification Summary"
    
    local pass_rate=$((CHECKS_PASSED * 100 / CHECKS_TOTAL))
    
    echo "Total Checks: $CHECKS_TOTAL"
    echo -e "Passed: ${GREEN}$CHECKS_PASSED${NC}"
    echo -e "Failed: ${RED}$CHECKS_FAILED${NC}"
    echo "Pass Rate: $pass_rate%"
    echo ""
    
    if [[ $CHECKS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}✓ All checks passed! Server is properly initialized.${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠ Some checks failed. Please review the items above.${NC}"
        return 1
    fi
}

# Print recommendations
print_recommendations() {
    print_header "Post-Initialization Recommendations"
    
    echo "1. SSH Key Setup (if not already done):"
    echo "   sudo bash manage-user.sh add ~/.ssh/id_rsa.pub"
    echo ""
    
    echo "2. Change Default Password:"
    echo "   passwd"
    echo ""
    
    echo "3. Update System:"
    echo "   sudo apt-get update && sudo apt-get upgrade"
    echo ""
    
    echo "4. Configure Additional Settings:"
    echo "   sudo bash advanced-config.sh --help"
    echo ""
    
    echo "5. Monitor Logs:"
    echo "   tail -f /var/log/vpc-init/*.log"
    echo ""
}

# Main execution
main() {
    echo -e "${BLUE}"
    cat << "EOF"
╔══════════════════════════════════════════════════════════╗
║     Server Initialization Verification Report            ║
╚══════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}\n"
    
    # Run checks
    check_system_info
    check_user_exists
    check_home_directory
    check_sudo
    check_ssh
    check_ssh_keys
    check_packages
    check_ssh_service
    check_firewall
    check_credentials
    check_logs
    
    # Print results
    print_summary
    local result=$?
    
    # Print recommendations
    if [[ $result -eq 0 ]]; then
        print_recommendations
    fi
    
    return $result
}

# Run if not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
