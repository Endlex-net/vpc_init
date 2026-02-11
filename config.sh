#!/bin/bash

################################################################################
# Configuration Manager
# Purpose: Load and parse TOML configuration files
# Format: TOML (Tom's Obvious, Minimal Language)
################################################################################

# Default configuration values
declare -gA CONFIG=(
    [username]="endlex"
    [timezone]="Asia/Shanghai"
    [swap_size]="2G"
    [enable_bbr]="true"
    [enable_p10k]="true"
    [enable_docker]="false"
    [enable_security]="true"
    [enable_limits]="true"
    [ssh_keys]=""
    [apt_packages]="curl,wget,git,build-essential,htop,net-tools,vim,nano,openssh-server"
)

################################################################################
# TOML Parser Functions
################################################################################

# Check Bash version for associative arrays
if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]; then
    echo "Error: Bash 4+ required for associative arrays" >&2
    exit 1
fi

# Simple TOML parser for basic key-value pairs
parse_toml() {
    local toml_file="$1"
    local section=""
    local line_num=0
    
    if [[ ! -f "$toml_file" ]]; then
        echo "Error: TOML file not found: $toml_file" >&2
        return 1
    fi
    
    while IFS= read -r line; do
        ((line_num++))
        
        # Skip empty lines and comments (including inline comments)
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        
        # Remove inline comments
        line="${line%%#*}"
        line="${line%"${line##*[^[:space:]]}"}"  # trim trailing whitespace
        
        # Parse section headers [section]
        if [[ "$line" =~ ^\[([^\]]+)\] ]]; then
            section="${BASH_REMATCH[1]}"
            continue
        fi
        
        # Parse key-value pairs
        if [[ "$line" =~ ^[[:space:]]*([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*=[[:space:]]*(.*) ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            
            # Trim leading whitespace from value
            value="${value#"${value%%[^[:space:]]*}"}"
            
            # Handle different value types
            if [[ "$value" =~ ^\"(.*)\"$ ]]; then
                # Double quoted string
                value="${BASH_REMATCH[1]}"
            elif [[ "$value" =~ ^\'(.*)\'$ ]]; then
                # Single quoted string
                value="${BASH_REMATCH[1]}"
            elif [[ "$value" =~ ^true|false$ ]]; then
                # Boolean value - keep as is
                :
            elif [[ "$value" =~ ^[0-9]+$ ]]; then
                # Integer value - keep as is
                :
            fi
            
            # Create section-prefixed key
            local full_key="${section}:${key}"
            if [[ -z "$section" ]]; then
                full_key="$key"
            fi
            
            CONFIG["$full_key"]="$value"
        elif [[ -n "$line" && ! "$line" =~ ^[[:space:]]*$ ]]; then
            # Invalid line format (non-empty, non-comment, non-section, non-key-value)
            echo "Warning: Ignoring malformed line $line_num: $line" >&2
        fi
    done < "$toml_file"
    
    return 0
}

# Get configuration value
get_config() {
    local key="$1"
    local default="${2:-}"
    
    if [[ -n "${CONFIG[$key]:-}" ]]; then
        echo "${CONFIG[$key]}"
    else
        echo "$default"
    fi
}

# Get configuration with section prefix
get_config_section() {
    local section="$1"
    local key="$2"
    local default="${3:-}"
    
    get_config "${section}:${key}" "$default"
}

# Validate configuration
validate_config() {
    local errors=()
    
    # Check timezone format
    local tz=$(get_config "timezone")
    if [[ ! -d "/usr/share/zoneinfo/$tz" ]]; then
        errors+=("Invalid timezone: $tz")
    fi
    
    # Check username format
    local username=$(get_config "username")
    if ! [[ "$username" =~ ^[a-zA-Z_][a-zA-Z0-9_-]{0,31}$ ]]; then
        errors+=("Invalid username format: $username")
    fi
    
    # Check swap size format
    local swap=$(get_config "swap_size")
    if ! [[ "$swap" =~ ^[0-9]+[GMK]?$ ]]; then
        errors+=("Invalid swap size format: $swap (use format like 2G, 1024M)")
    fi
    
    if [[ ${#errors[@]} -gt 0 ]]; then
        echo "Configuration validation errors:" >&2
        for error in "${errors[@]}"; do
            echo "  • $error" >&2
        done
        return 1
    fi
    
    return 0
}

# Print configuration
print_config() {
    echo "Current Configuration:"
    echo "===================="
    echo ""
    echo "Basic Settings:"
    echo "  username: $(get_config 'basic:username' "$(get_config 'username')")"
    echo "  timezone: $(get_config 'basic:timezone' "$(get_config 'timezone')")"
    echo "  swap_size: $(get_config 'basic:swap_size' "$(get_config 'swap_size')")"
    echo ""
    echo "Features:"
    echo "  bbr: $(get_config 'features:bbr' "$(get_config 'enable_bbr')")"
    echo "  p10k: $(get_config 'features:p10k' "$(get_config 'enable_p10k')")"
    echo "  docker: $(get_config 'features:docker' "$(get_config 'enable_docker')")"
    echo "  security: $(get_config 'features:security' "$(get_config 'enable_security')")"
    echo "  limits: $(get_config 'features:limits' "$(get_config 'enable_limits')")"
    echo ""
    echo "Additional Packages:"
    echo "  $(get_config 'packages:additional' "$(get_config 'apt_packages')")"
    echo ""
}

# Check if config key exists
config_exists() {
    local key="$1"
    [[ -n "${CONFIG[$key]:-}" ]]
}

# Get all keys with a prefix
get_config_keys() {
    local prefix="$1"
    for key in "${!CONFIG[@]}"; do
        if [[ "$key" == "$prefix"* ]]; then
            echo "$key"
        fi
    done
}

# Export configuration functions
export -f parse_toml
export -f get_config
export -f get_config_section
export -f validate_config
export -f print_config
export -f config_exists
export -f get_config_keys
