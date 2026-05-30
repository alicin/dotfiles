#!/bin/bash

# Profile management library
# Provides functions to work with profile-based configurations

# Parse JSON profile configuration
parse_profile() {
    local profile_path="$1"
    
    if [[ ! -f "$profile_path" ]]; then
        log_error "Profile configuration not found: $profile_path"
        return 1
    fi
    
    # Check if jq is available
    if ! command -v jq >/dev/null 2>&1; then
        log_error "jq is required to parse profile configurations"
        return 1
    fi
    
    PROFILE_JSON="$profile_path"
}

# Get profile field value
get_profile_field() {
    local field="$1"
    local default_value="$2"
    
    if [[ -z "$PROFILE_JSON" ]]; then
        log_error "No profile loaded"
        return 1
    fi
    
    local value=$(jq -r ".$field // empty" "$PROFILE_JSON" 2>/dev/null)
    echo "${value:-$default_value}"
}

# Get profile array field
get_profile_array() {
    local field="$1"
    
    if [[ -z "$PROFILE_JSON" ]]; then
        log_error "No profile loaded"
        return 1
    fi
    
    jq -r ".$field[]? // empty" "$PROFILE_JSON" 2>/dev/null
}

# Check if profile feature is enabled
is_feature_enabled() {
    local feature="$1"
    
    local enabled=$(get_profile_field "features.$feature" "false")
    [[ "$enabled" == "true" ]]
}

# Get package manager configuration
get_package_manager_config() {
    local pm_name="$1"
    local config_field="$2"
    
    get_profile_field "package_managers.$pm_name.$config_field"
}

# Check if package manager is enabled
is_package_manager_enabled() {
    local pm_name="$1"
    
    local enabled=$(get_package_manager_config "$pm_name" "enabled")
    [[ "$enabled" == "true" ]]
}

# Get package manager file
get_package_manager_file() {
    local pm_name="$1"
    
    get_package_manager_config "$pm_name" "file"
}

# List available profiles
list_available_profiles() {
    local profiles_dir="$1"
    
    if [[ ! -d "$profiles_dir" ]]; then
        log_error "Profiles directory not found: $profiles_dir"
        return 1
    fi
    
    for profile_dir in "$profiles_dir"/*; do
        if [[ -d "$profile_dir" && -f "$profile_dir/profile.json" ]]; then
            local profile_name=$(basename "$profile_dir")
            local description=$(jq -r '.description // "No description"' "$profile_dir/profile.json" 2>/dev/null)
            printf "  %-20s %s\n" "$profile_name" "$description"
        fi
    done
}

# Validate profile exists and is valid
validate_profile() {
    local profiles_dir="$1"
    local profile_name="$2"
    
    local profile_path="$profiles_dir/$profile_name/profile.json"
    
    if [[ ! -f "$profile_path" ]]; then
        log_error "Profile '$profile_name' not found"
        echo ""
        echo "Available profiles:"
        list_available_profiles "$profiles_dir"
        return 1
    fi
    
    # Validate JSON syntax
    if ! jq empty "$profile_path" >/dev/null 2>&1; then
        log_error "Invalid JSON in profile configuration: $profile_path"
        return 1
    fi
    
    # Load the profile
    parse_profile "$profile_path"
    
    return 0
}

# Get profile directory
get_profile_dir() {
    local profiles_dir="$1"
    local profile_name="$2"
    
    echo "$profiles_dir/$profile_name"
}

# Auto-detect profile based on hostname and OS
auto_detect_profile() {
    local profiles_dir="$1"
    local current_hostname=$(hostname)
    local current_os="$DETECTED_OS"
    
    log_info "Auto-detecting profile for hostname: $current_hostname, OS: $current_os" >&2
    
    for profile_dir in "$profiles_dir"/*; do
        if [[ -d "$profile_dir" && -f "$profile_dir/profile.json" ]]; then
            local profile_hostname=$(jq -r '.hostname // empty' "$profile_dir/profile.json" 2>/dev/null)
            local profile_os=$(jq -r '.os // empty' "$profile_dir/profile.json" 2>/dev/null)
            
            # Check for exact hostname match
            if [[ "$profile_hostname" == "$current_hostname"* || "$current_hostname" == "$profile_hostname"* ]]; then
                if [[ "$profile_os" == "$current_os" ]]; then
                    local profile_name=$(basename "$profile_dir")
                    log_success "Auto-detected profile: $profile_name" >&2
                    echo "$profile_name"
                    return 0
                fi
            fi
        fi
    done
    
    log_warning "Could not auto-detect profile for current system" >&2
    return 1
} 