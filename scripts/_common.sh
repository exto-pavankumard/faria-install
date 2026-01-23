#!/bin/bash
#
# Faria Installation Scripts - Common Utilities
# This file is inlined by the build system into the single-file installer.
# Do not execute directly.
#

# ============================================================================
# COLORS
# ============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ============================================================================
# OS DETECTION
# ============================================================================

# Detect operating system and architecture
# Sets: OS, ARCH
detect_os() {
    OS="$(uname -s)"
    ARCH="$(uname -m)"
    export OS ARCH
}

# Detect Linux distribution
# Sets: DISTRO
detect_linux_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO="${ID}"
    elif [ -f /etc/lsb-release ]; then
        . /etc/lsb-release
        DISTRO="${DISTRIB_ID,,}"
    else
        DISTRO="unknown"
    fi
    export DISTRO
}

# Detect package manager
# Sets: PKG_MGR
detect_package_manager() {
    if command -v brew &> /dev/null; then
        PKG_MGR="brew"
    elif command -v apt &> /dev/null; then
        PKG_MGR="apt"
    elif command -v dnf &> /dev/null; then
        PKG_MGR="dnf"
    elif command -v pacman &> /dev/null; then
        PKG_MGR="pacman"
    elif command -v zypper &> /dev/null; then
        PKG_MGR="zypper"
    else
        PKG_MGR="unknown"
    fi
    export PKG_MGR
}

# ============================================================================
# DOWNLOAD HELPERS
# ============================================================================

# Download a file using curl or wget
# Args: $1 = URL, $2 = destination path
# Returns: 0 on success, 1 on failure
download_file() {
    local url="$1"
    local dest="$2"

    if command -v curl &> /dev/null; then
        curl -fSL --progress-bar -o "${dest}" "${url}"
    elif command -v wget &> /dev/null; then
        wget -q --show-progress -O "${dest}" "${url}"
    else
        echo -e "${RED}Error: Neither curl nor wget found. Please install one.${NC}"
        return 1
    fi
}

# Download a file silently (no progress bar)
# Args: $1 = URL, $2 = destination path
download_file_silent() {
    local url="$1"
    local dest="$2"

    if command -v curl &> /dev/null; then
        curl -fsSL -o "${dest}" "${url}"
    elif command -v wget &> /dev/null; then
        wget -q -O "${dest}" "${url}"
    else
        echo -e "${RED}Error: Neither curl nor wget found. Please install one.${NC}"
        return 1
    fi
}

# ============================================================================
# VERSION COMPARISON
# ============================================================================

# Compare two semantic versions
# Returns: 0 if $1 >= $2, 1 otherwise
# Args: $1 = current version, $2 = minimum version
version_gte() {
    local current=$1
    local min=$2
    if [[ "$(printf '%s\n' "$min" "$current" | sort -V | head -n1)" == "$min" ]]; then
        return 0
    else
        return 1
    fi
}

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

# Check if a command exists
# Args: $1 = command name
command_exists() {
    command -v "$1" &> /dev/null
}

# Create a temporary directory and set up cleanup trap
# Sets: WORK_DIR
# Usage: setup_temp_dir; trap cleanup_temp_dir EXIT
setup_temp_dir() {
    WORK_DIR=$(mktemp -d)
    export WORK_DIR
}

# Clean up temporary directory
cleanup_temp_dir() {
    if [ -n "${WORK_DIR}" ] && [ -d "${WORK_DIR}" ]; then
        rm -rf "${WORK_DIR}"
    fi
}

# Print a section header
# Args: $1 = header text
print_header() {
    local text="$1"
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  ${text}${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

# Print a step header
# Args: $1 = step number, $2 = total steps, $3 = step name
print_step() {
    local step="$1"
    local total="$2"
    local name="$3"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  Step ${step}/${total}: ${name}${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# Check if running in interactive mode (not piped)
is_interactive() {
    [ -t 0 ]
}

# Prompt for yes/no confirmation
# Args: $1 = prompt message, $2 = default (y/n)
# Returns: 0 for yes, 1 for no
confirm() {
    local prompt="$1"
    local default="${2:-n}"

    if ! is_interactive; then
        # Non-interactive mode: use default
        [[ "$default" =~ ^[Yy]$ ]] && return 0 || return 1
    fi

    local reply
    read -p "${prompt} " -n 1 -r reply
    echo
    [[ "$reply" =~ ^[Yy]$ ]] && return 0 || return 1
}
