#!/bin/bash

# Logging functions for consistent output across scripts
# Usage: source this file and use the logging functions

# Source colors
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${LIB_DIR}/colors.sh"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${RESET} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${RESET} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${RESET} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${RESET} $1" >&2
}

log_debug() {
    if [[ "${DEBUG:-0}" == "1" ]]; then
        echo -e "${PURPLE}[DEBUG]${RESET} $1"
    fi
}

# Progress indicators
log_step() {
    echo -e "${CYAN}→${RESET} $1"
}

log_substep() {
    echo -e "  ${CYAN}•${RESET} $1"
}

# Header for major sections
log_header() {
    echo ""
    echo -e "${BOLD_BLUE}===================================================${RESET}"
    echo -e "${BOLD_BLUE} $1${RESET}"
    echo -e "${BOLD_BLUE}===================================================${RESET}"
    echo ""
} 