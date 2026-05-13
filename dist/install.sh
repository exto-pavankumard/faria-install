#!/bin/bash
#
# Faria Installation Script - Single-file Installer
# AUTO-GENERATED FILE - DO NOT EDIT DIRECTLY
#
# Generated from modular source files by build/build.sh
# Source: https://github.com/exto360-inc/faria-install
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/exto360-inc/faria-install/main/dist/install.sh | bash -s -- --features idp
#   curl -fsSL https://raw.githubusercontent.com/exto360-inc/faria-install/main/dist/install.sh | bash -s -- --features chat
#   curl -fsSL https://raw.githubusercontent.com/exto360-inc/faria-install/main/dist/install.sh | bash -s -- --features all
#

set -e

# Build date: 2026-05-13T14:19:47Z
# GitHub URL: https://raw.githubusercontent.com/exto360-inc/faria-install/main

# ============================================================================
# Common Utilities (from scripts/_common.sh)
# ============================================================================

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


# ============================================================================
# Models Cache Helper (downloads Python scripts from GitHub)
# ============================================================================
MODELS_CACHE_DIR=""

__setup_models_cache() {
    if [ -n "${MODELS_CACHE_DIR}" ] && [ -d "${MODELS_CACHE_DIR}" ]; then
        return 0
    fi

    MODELS_CACHE_DIR=$(mktemp -d)
    mkdir -p "${MODELS_CACHE_DIR}"

    echo -e "${YELLOW}Downloading model export scripts from GitHub...${NC}"

    local base_url="https://raw.githubusercontent.com/exto360-inc/faria-install/main/models"

    download_file_silent "${base_url}/requirements-detr.txt" "${MODELS_CACHE_DIR}/requirements-detr.txt" || return 1
    download_file_silent "${base_url}/requirements-nemotron.txt" "${MODELS_CACHE_DIR}/requirements-nemotron.txt" || return 1
    download_file_silent "${base_url}/export_detr_layout_onnx.py" "${MODELS_CACHE_DIR}/export_detr_layout_onnx.py" || return 1
    download_file_silent "${base_url}/export_nemotron_onnx.py" "${MODELS_CACHE_DIR}/export_nemotron_onnx.py" || return 1

    echo -e "${GREEN}Model scripts downloaded.${NC}"
}

__cleanup_models_cache() {
    if [ -n "${MODELS_CACHE_DIR}" ] && [ -d "${MODELS_CACHE_DIR}" ]; then
        rm -rf "${MODELS_CACHE_DIR}"
        MODELS_CACHE_DIR=""
    fi
}


# ============================================================================
# __setup_python() - from setup-python.sh
# ============================================================================
__setup_python() {
    #
    # Faria Python Setup Script
    # Ensures Python 3.12.x is available (required for onnxruntime compatibility)
    #
    # Usage: __setup_python
    #   Sets PYTHON_CMD to the path of a compatible Python interpreter
    #
    # Or: ./setup-python.sh
    #   Prints the path to the Python interpreter
    #
    
    # Colors for output
    
    # Detect OS
    OS="$(uname -s)"
    
    # Required Python version
    REQUIRED_MAJOR=3
    REQUIRED_MINOR=12
    
    function _local_check_python_version {
        local python_bin="$1"
        if [ ! -x "$python_bin" ] && ! command -v "$python_bin" &> /dev/null; then
            return 1
        fi
    
        local version=$("$python_bin" --version 2>&1 | cut -d' ' -f2)
        local major=$(echo "$version" | cut -d'.' -f1)
        local minor=$(echo "$version" | cut -d'.' -f2)
    
        if [ "$major" = "$REQUIRED_MAJOR" ] && [ "$minor" = "$REQUIRED_MINOR" ]; then
            echo "$version"
            return 0
        fi
        return 1
    }
    
    function _local_find_compatible_python {
        # Check common Python 3.12 paths
        local candidates=(
            "python3.12"
            "python3"
            "python"
            "/opt/homebrew/bin/python3.12"
            "/usr/local/bin/python3.12"
            "/usr/bin/python3.12"
        )
    
        for candidate in "${candidates[@]}"; do
            if version=$(check_python_version "$candidate"); then
                if command -v "$candidate" &> /dev/null; then
                    echo "$(command -v "$candidate")"
                else
                    echo "$candidate"
                fi
                return 0
            fi
        done
    
        return 1
    }
    
    function _local_setup_pyenv {
        echo -e "${YELLOW}Setting up Python ${REQUIRED_MAJOR}.${REQUIRED_MINOR} via pyenv...${NC}" >&2
    
        # Check if pyenv is installed
        if ! command -v pyenv &> /dev/null; then
            echo -e "${YELLOW}pyenv not found. Installing pyenv...${NC}" >&2
    
            if [ "$OS" = "Darwin" ]; then
                if command -v brew &> /dev/null; then
                    brew install pyenv
                else
                    echo -e "${RED}Error: Homebrew not found. Please install Homebrew first:${NC}" >&2
                    echo "  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"" >&2
                    return 1
                fi
            else
                # Linux
                echo -e "${YELLOW}Installing pyenv via pyenv-installer...${NC}" >&2
                curl https://pyenv.run | bash
    
                # Add to current shell
                export PYENV_ROOT="$HOME/.pyenv"
                export PATH="$PYENV_ROOT/bin:$PATH"
            fi
        fi
    
        # Initialize pyenv for this shell
        export PYENV_ROOT="${PYENV_ROOT:-$HOME/.pyenv}"
        export PATH="$PYENV_ROOT/bin:$PATH"
    
        if command -v pyenv &> /dev/null; then
            eval "$(pyenv init -)"
        else
            echo -e "${RED}Error: pyenv installation failed.${NC}" >&2
            return 1
        fi
    
        # Check if Python 3.12 is already installed via pyenv
        local pyenv_312_version=$(pyenv versions --bare 2>/dev/null | grep "^${REQUIRED_MAJOR}\.${REQUIRED_MINOR}\." | tail -1)
    
        if [ -z "$pyenv_312_version" ]; then
            echo -e "${YELLOW}Installing Python ${REQUIRED_MAJOR}.${REQUIRED_MINOR} via pyenv...${NC}" >&2
            echo "  This may take several minutes..." >&2
    
            # Find latest 3.12.x version available
            local latest_312=$(pyenv install --list 2>/dev/null | grep -E "^\s*${REQUIRED_MAJOR}\.${REQUIRED_MINOR}\.[0-9]+$" | tail -1 | tr -d ' ')
    
            if [ -z "$latest_312" ]; then
                echo -e "${RED}Error: Could not find Python ${REQUIRED_MAJOR}.${REQUIRED_MINOR}.x in pyenv.${NC}" >&2
                echo "  Try running: pyenv install --list | grep ${REQUIRED_MAJOR}.${REQUIRED_MINOR}" >&2
                return 1
            fi
    
            pyenv install "$latest_312"
            pyenv_312_version="$latest_312"
        fi
    
        echo -e "${GREEN}Using pyenv Python: ${pyenv_312_version}${NC}" >&2
    
        # Return the full path to the Python binary
        echo "$(pyenv root)/versions/${pyenv_312_version}/bin/python3"
    }
    
    # Main logic
    echo -e "${YELLOW}Checking Python version...${NC}" >&2
    
    # First try to find a compatible Python
    if python_path=$(find_compatible_python); then
        version=$(check_python_version "$python_path")
        echo -e "${GREEN}Found Python ${version} at: ${python_path}${NC}" >&2
        PYTHON_CMD="$python_path"
    else
        # Check what version we have
        if command -v python3 &> /dev/null; then
            current_version=$(python3 --version 2>&1 | cut -d' ' -f2)
            echo -e "${YELLOW}System Python is ${current_version} (need ${REQUIRED_MAJOR}.${REQUIRED_MINOR}.x for onnxruntime)${NC}" >&2
        else
            echo -e "${YELLOW}No Python found${NC}" >&2
        fi
    
        # Use pyenv to get the right version
        PYTHON_CMD=$(setup_pyenv)
    fi
    
    # If sourced, export the variable; if run directly, print the path
    if [ -n "$PYTHON_CMD" ]; then
        # Export for sourcing
        export PYTHON_CMD
    
        # Print path if run directly (not sourced)
        if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
            echo "$PYTHON_CMD"
        fi
    else
        echo -e "${RED}Error: Could not find or install Python ${REQUIRED_MAJOR}.${REQUIRED_MINOR}${NC}" >&2
        return 1
    fi
}

# ============================================================================
# __install_opencv() - from install-opencv.sh
# ============================================================================
__install_opencv() {
    #
    # Faria OpenCV Installation Script
    # Tries to download pre-built binaries from GitHub Releases first.
    # Falls back to building from source if the download fails or the
    # binary cannot be verified.
    #
    # Usage: ./install-opencv.sh [OPTIONS]
    #
    
    
    OPENCV_VERSION="4.12.0"
    
    # Colors for output
    
    INSTALL_DIR="${HOME}/.faria"
    FORCE=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --install-dir)
                INSTALL_DIR="$2"
                shift 2
                ;;
            --force|-f)
                FORCE=true
                shift
                ;;
            --help|-h)
                echo "Faria OpenCV Installation Script"
                echo ""
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --install-dir DIR  Install to DIR (default: ~/.faria)"
                echo "  --force, -f        Reinstall even if already present"
                echo "  --help, -h         Show this help message"
                return 0
                ;;
            *)
                echo "Unknown option: $1"
                return 1
                ;;
        esac
    done
    
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  Faria OpenCV Installation${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    
    OS="$(uname -s)"
    ARCH="$(uname -m)"
    
    echo -e "${YELLOW}Detecting system...${NC}"
    echo "  OS: ${OS}"
    echo "  Architecture: ${ARCH}"
    
    case "${OS}" in
        Darwin|Linux) ;;
        *)
            echo -e "${RED}Unsupported OS: ${OS}${NC}"
            echo "For Windows, please use install-opencv.ps1"
            return 1
            ;;
    esac
    
    # Pick release asset; leave empty when no pre-built exists for this platform.
    # An empty OPENCV_ASSET causes _try_release to skip straight to fallback.
    case "${OS}-${ARCH}" in
        Linux-x86_64)  OPENCV_ASSET="opencv-${OPENCV_VERSION}-linux-x86_64.zip" ;;
        Darwin-arm64)  OPENCV_ASSET="opencv-${OPENCV_VERSION}-macos-arm64.zip"  ;;
        *)             OPENCV_ASSET=""  ;;
    esac
    
    RELEASE_REPO="${FARIA_RELEASE_REPO:-exto360-inc/faria-install}"
    OPENCV_DIR="${INSTALL_DIR}/lib/opencv"
    OPENCV_URL="https://github.com/${RELEASE_REPO}/releases/download/opencv-${OPENCV_VERSION}/${OPENCV_ASSET}"
    CHECKSUMS_URL="https://github.com/${RELEASE_REPO}/releases/download/opencv-${OPENCV_VERSION}/checksums.txt"
    
    echo ""
    echo -e "${YELLOW}Installation configuration:${NC}"
    echo "  Install directory: ${OPENCV_DIR}"
    echo "  OpenCV version:    ${OPENCV_VERSION}"
    echo ""
    
    # Already installed? Also accept a system/brew install visible via pkg-config.
    if [ "${FORCE}" = false ]; then
        if [ -f "${OPENCV_DIR}/lib/pkgconfig/opencv4.pc" ]; then
            echo -e "${GREEN}OpenCV ${OPENCV_VERSION} already installed at ${OPENCV_DIR}${NC}"
            return 0
        elif pkg-config --exists opencv4 2>/dev/null; then
            VER=$(pkg-config --modversion opencv4 2>/dev/null)
            echo -e "${GREEN}OpenCV already available via pkg-config (v${VER}) — skipping installation.${NC}"
            return 0
        fi
    fi
    
    mkdir -p "${OPENCV_DIR}"
    
    TEMP_DIR=$(mktemp -d)
    trap "rm -rf '${TEMP_DIR}'" EXIT
    
    # ============================================================================
    # _try_release: attempt pre-built download.
    #
    # NOTE: bash disables set -e for the entire body of a function called as the
    # condition of an `if` statement. Each critical step must use `|| return 1`
    # so that a failure causes the function to return non-zero for the caller.
    # ============================================================================
    _try_release() {
        if [ -z "${OPENCV_ASSET}" ]; then
            echo -e "${YELLOW}  No pre-built release for ${OS}/${ARCH} — will build from source.${NC}"
            return 1
        fi
    
        echo "  Asset: ${OPENCV_ASSET}"
        echo ""
    
        # --- Download ---
        echo -e "${YELLOW}Downloading OpenCV ${OPENCV_VERSION} pre-built tarball...${NC}"
        echo "  URL: ${OPENCV_URL}"
        if command -v curl &>/dev/null; then
            curl -fSL --progress-bar -o "${TEMP_DIR}/${OPENCV_ASSET}" "${OPENCV_URL}" || \
                { echo -e "${YELLOW}  Download failed.${NC}"; return 1; }
        elif command -v wget &>/dev/null; then
            wget -q --show-progress -O "${TEMP_DIR}/${OPENCV_ASSET}" "${OPENCV_URL}" || \
                { echo -e "${YELLOW}  Download failed.${NC}"; return 1; }
        else
            echo -e "${YELLOW}  Neither curl nor wget found.${NC}"; return 1
        fi
    
        # Sanity-check: a valid pre-built zip should be at least 5 MB
        local file_size
        file_size=$(wc -c < "${TEMP_DIR}/${OPENCV_ASSET}" | tr -d ' ')
        if [ "${file_size}" -lt 5242880 ]; then
            echo -e "${YELLOW}  Downloaded file is only ${file_size} bytes — not a valid binary release.${NC}"
            return 1
        fi
        echo -e "${GREEN}  Download complete.${NC}"
        echo ""
    
        # --- Checksum ---
        echo -e "${YELLOW}Verifying checksum...${NC}"
        if command -v curl &>/dev/null; then
            curl -fsSL -o "${TEMP_DIR}/checksums.txt" "${CHECKSUMS_URL}" 2>/dev/null || true
        else
            wget -q -O "${TEMP_DIR}/checksums.txt" "${CHECKSUMS_URL}" 2>/dev/null || true
        fi
        if [ -f "${TEMP_DIR}/checksums.txt" ]; then
            local expected actual
            expected=$(grep "${OPENCV_ASSET}" "${TEMP_DIR}/checksums.txt" | awk '{print $1}')
            if [ -n "${expected}" ]; then
                if command -v sha256sum &>/dev/null; then
                    actual=$(sha256sum "${TEMP_DIR}/${OPENCV_ASSET}" | awk '{print $1}')
                elif command -v shasum &>/dev/null; then
                    actual=$(shasum -a 256 "${TEMP_DIR}/${OPENCV_ASSET}" | awk '{print $1}')
                fi
                if [ -n "${actual}" ] && [ "${actual}" != "${expected}" ]; then
                    echo -e "${YELLOW}  Checksum mismatch — release binary may be corrupt.${NC}"
                    return 1
                fi
                [ -n "${actual}" ] && echo -e "${GREEN}  Checksum OK.${NC}"
            else
                echo -e "${YELLOW}  No checksum entry for ${OPENCV_ASSET} — skipping verify.${NC}"
            fi
        fi
        echo ""
    
        # --- Extract ---
        echo -e "${YELLOW}Extracting OpenCV...${NC}"
        if ! command -v unzip &>/dev/null; then
            echo -e "${YELLOW}  unzip not found — cannot use pre-built archive.${NC}"
            return 1
        fi
        local extract_dir="${TEMP_DIR}/opencv-extract"
        mkdir -p "${extract_dir}"
        unzip -q "${TEMP_DIR}/${OPENCV_ASSET}" -d "${extract_dir}" || \
            { echo -e "${YELLOW}  Extraction failed.${NC}"; return 1; }
    
        local root_dirs root_files
        root_dirs=$(find "${extract_dir}" -maxdepth 1 -mindepth 1 -type d | wc -l | tr -d ' ')
        root_files=$(find "${extract_dir}" -maxdepth 1 -mindepth 1 -type f | wc -l | tr -d ' ')
        if [ "${root_dirs}" -eq 1 ] && [ "${root_files}" -eq 0 ]; then
            local wrapper
            wrapper=$(find "${extract_dir}" -maxdepth 1 -mindepth 1 -type d | head -1)
            rm -rf "${OPENCV_DIR}"
            mv "${wrapper}" "${OPENCV_DIR}"
        else
            rm -rf "${OPENCV_DIR}"
            mv "${extract_dir}" "${OPENCV_DIR}"
        fi
        echo -e "${GREEN}  Extracted to: ${OPENCV_DIR}${NC}"
        echo ""
    
        # Sanity-check: archive must contain opencv4.pc
        if [ ! -f "${OPENCV_DIR}/lib/pkgconfig/opencv4.pc" ]; then
            echo -e "${YELLOW}  opencv4.pc missing from archive — binary may be incomplete.${NC}"
            return 1
        fi
    
        # Fix prefix in opencv4.pc
        echo -e "${YELLOW}Registering opencv4.pc with pkg-config...${NC}"
        sed -i.bak "s|^prefix=.*|prefix=${OPENCV_DIR}|" "${OPENCV_DIR}/lib/pkgconfig/opencv4.pc"
        rm -f "${OPENCV_DIR}/lib/pkgconfig/opencv4.pc.bak"
        echo -e "${GREEN}  opencv4.pc prefix updated to ${OPENCV_DIR}.${NC}"
        echo ""
    
        return 0
    }
    
    # ============================================================================
    # _build_from_source: build OpenCV from source.
    # Called outside an `if` condition, so set -e applies normally.
    # ============================================================================
    _build_from_source() {
        echo -e "${YELLOW}Building OpenCV ${OPENCV_VERSION} from source...${NC}"
        echo ""
    
        case "${OS}" in
            Darwin)
                if ! command -v brew &>/dev/null; then
                    echo -e "${RED}Error: Homebrew is not installed.${NC}"
                    echo "Install it from https://brew.sh then re-run this script."
                    return 1
                fi
                echo -e "${YELLOW}Installing via Homebrew (this may take several minutes)...${NC}"
                brew install opencv
                # Redirect OPENCV_DIR to the brew prefix so pkg-config resolution works
                OPENCV_DIR="$(brew --prefix opencv)"
                ;;
    
            Linux)
                local distro=""
                [ -f /etc/os-release ] && { . /etc/os-release; distro="${ID}"; }
                echo "  Distribution: ${distro:-unknown}"
                echo ""
    
                echo -e "${YELLOW}Installing build dependencies...${NC}"
                case "${distro}" in
                    ubuntu|debian|linuxmint|pop)
                        sudo apt-get update -q
                        sudo apt-get install -y --no-install-recommends \
                            build-essential cmake pkg-config unzip \
                            libjpeg-dev libpng-dev libtiff-dev
                        ;;
                    fedora|rhel|centos|rocky|almalinux)
                        sudo dnf install -y gcc gcc-c++ cmake pkgconfig unzip \
                            libjpeg-turbo-devel libpng-devel libtiff-devel
                        ;;
                    arch|manjaro|endeavouros)
                        sudo pacman -S --noconfirm base-devel cmake pkgconf unzip \
                            libjpeg-turbo libpng libtiff
                        ;;
                    opensuse*)
                        sudo zypper install -y gcc gcc-c++ cmake pkg-config unzip \
                            libjpeg62-devel libpng16-devel libtiff-devel
                        ;;
                    *)
                        echo -e "${YELLOW}  Unknown distro — skipping automatic dependency install.${NC}"
                        echo "  Ensure cmake, gcc, and image codec dev libs are installed."
                        ;;
                esac
                echo ""
    
                # Download source
                local src_url="https://github.com/opencv/opencv/archive/refs/tags/${OPENCV_VERSION}.tar.gz"
                echo -e "${YELLOW}Downloading OpenCV ${OPENCV_VERSION} source...${NC}"
                if command -v curl &>/dev/null; then
                    curl -fSL --progress-bar -o "${TEMP_DIR}/opencv.tar.gz" "${src_url}"
                else
                    wget -q --show-progress -O "${TEMP_DIR}/opencv.tar.gz" "${src_url}"
                fi
                tar -xzf "${TEMP_DIR}/opencv.tar.gz" -C "${TEMP_DIR}"
                echo ""
    
                # Build and install to OPENCV_DIR (no sudo needed — user-space dir)
                local jobs
                jobs=$(nproc 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null || echo 2)
                echo -e "${YELLOW}Building OpenCV ${OPENCV_VERSION} (${jobs} jobs — this may take 10-20 minutes)...${NC}"
                cmake "${TEMP_DIR}/opencv-${OPENCV_VERSION}" \
                    -B "${TEMP_DIR}/opencv_build" \
                    -DCMAKE_BUILD_TYPE=Release \
                    -DCMAKE_INSTALL_PREFIX="${OPENCV_DIR}" \
                    -DOPENCV_GENERATE_PKGCONFIG=ON \
                    -DBUILD_LIST=core,imgproc,imgcodecs,objdetect,features2d,photo,calib3d,video,videoio,dnn,highgui \
                    -DBUILD_TESTS=OFF -DBUILD_PERF_TESTS=OFF -DBUILD_EXAMPLES=OFF \
                    -DBUILD_SHARED_LIBS=ON \
                    -DBUILD_JPEG=ON -DBUILD_PNG=ON -DBUILD_TIFF=ON \
                    -DWITH_GTK=OFF -DWITH_QT=OFF -DWITH_OPENGL=OFF \
                    -DWITH_FFMPEG=OFF -DWITH_GSTREAMER=OFF -DWITH_V4L=OFF \
                    -DWITH_IPP=OFF -DBUILD_PROTOBUF=ON -DWITH_PROTOBUF=ON \
                    -DWITH_JASPER=OFF -DWITH_OPENEXR=OFF
                cmake --build "${TEMP_DIR}/opencv_build" --parallel "${jobs}"
                cmake --install "${TEMP_DIR}/opencv_build"
                echo -e "${GREEN}  Source build complete.${NC}"
                echo ""
                ;;
        esac
    }
    
    # ============================================================================
    # Main: try release, fall back to source on any failure
    # ============================================================================
    INSTALL_METHOD=""
    
    if _try_release; then
        INSTALL_METHOD="pre-built release"
    else
        echo -e "${YELLOW}Pre-built release unavailable or failed — falling back to build from source.${NC}"
        echo ""
        _build_from_source
        INSTALL_METHOD="source build"
    fi
    
    # ============================================================================
    # PKG_CONFIG_PATH — resolve after potential OPENCV_DIR update (brew changes it)
    # ============================================================================
    PKG_CONFIG_DIR="${OPENCV_DIR}/lib/pkgconfig"
    export PKG_CONFIG_PATH="${PKG_CONFIG_DIR}:${PKG_CONFIG_PATH:-}"
    
    # ============================================================================
    # Verify
    # ============================================================================
    echo -e "${YELLOW}Verifying installation...${NC}"
    
    LIB_CHECK=""
    case "${OS}" in
        Darwin) LIB_CHECK=$(find "${OPENCV_DIR}/lib" -maxdepth 2 -name "libopencv_core*.dylib" 2>/dev/null | head -1) ;;
        Linux)  LIB_CHECK=$(find "${OPENCV_DIR}/lib" -maxdepth 2 -name "libopencv_core*.so*"   2>/dev/null | head -1) ;;
    esac
    
    if [ -n "${LIB_CHECK}" ]; then
        echo -e "${GREEN}  OpenCV lib: $(basename "${LIB_CHECK}")${NC}"
    else
        echo -e "${YELLOW}  Warning: libopencv_core not found under ${OPENCV_DIR}/lib${NC}"
    fi
    
    if pkg-config --exists opencv4 2>/dev/null; then
        OPENCV_FOUND_VER=$(pkg-config --modversion opencv4)
        echo -e "${GREEN}  pkg-config opencv4: OK (v${OPENCV_FOUND_VER})${NC}"
    else
        echo -e "${YELLOW}  pkg-config opencv4: not found in current session (open a new shell or source your profile)${NC}"
    fi
    
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  Installation Complete!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo "Installed to: ${OPENCV_DIR}"
    echo "Method:       ${INSTALL_METHOD}"
    echo ""
    echo "Add this to your shell profile (~/.bashrc, ~/.zshrc, etc.):"
    echo ""
    echo "  export PKG_CONFIG_PATH=\"${PKG_CONFIG_DIR}:\$PKG_CONFIG_PATH\""
    echo ""
}

# ============================================================================
# __install_tesseract() - from install-tesseract.sh
# ============================================================================
__install_tesseract() {
    #
    # Faria Tesseract OCR Installation Script
    # Installs Tesseract OCR and Leptonica for text extraction
    #
    # Usage: ./install-tesseract.sh [OPTIONS]
    #
    # This script uses system package managers to install Tesseract.
    #
    
    
    # Colors for output
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                echo "Faria Tesseract OCR Installation Script"
                echo ""
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --help, -h         Show this help message"
                echo ""
                echo "This script installs Tesseract OCR using your system's package manager."
                echo "Supported platforms: macOS (Homebrew), Ubuntu/Debian, Fedora/RHEL, Arch Linux"
                return 0
                ;;
            *)
                echo "Unknown option: $1"
                return 1
                ;;
        esac
    done
    
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  Faria Tesseract OCR Installation${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    
    # Detect OS and architecture
    OS="$(uname -s)"
    
    echo -e "${YELLOW}Detecting system...${NC}"
    echo "  OS: ${OS}"
    
    # Check if Tesseract is already installed
    if command -v tesseract &> /dev/null; then
        TESSERACT_VERSION=$(tesseract --version 2>&1 | head -n1)
        echo ""
        echo -e "${GREEN}Tesseract is already installed:${NC}"
        echo "  ${TESSERACT_VERSION}"
        echo "  Path: $(which tesseract)"
        echo ""
        # In interactive mode offer to skip; in non-interactive always continue so
        # that leptonica-dev is installed even when tesseract was pre-installed.
        if [ -t 0 ]; then
            read -p "Do you want to reinstall/upgrade? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                echo -e "${GREEN}Skipping installation.${NC}"
                return 0
            fi
        else
            echo -e "${YELLOW}Non-interactive mode — ensuring leptonica dev libraries are installed.${NC}"
        fi
    fi
    
    echo ""
    
    # Install based on platform
    case "${OS}" in
        Darwin)
            echo -e "${YELLOW}Installing via Homebrew...${NC}"
            if ! command -v brew &> /dev/null; then
                echo -e "${RED}Error: Homebrew is not installed.${NC}"
                echo "Please install Homebrew first: https://brew.sh"
                return 1
            fi
    
            brew install tesseract leptonica
            ;;
        Linux)
            # Detect Linux distribution
            if [ -f /etc/os-release ]; then
                . /etc/os-release
                DISTRO="${ID}"
            elif [ -f /etc/lsb-release ]; then
                . /etc/lsb-release
                DISTRO="${DISTRIB_ID,,}"
            else
                DISTRO="unknown"
            fi
    
            echo "  Distribution: ${DISTRO}"
            echo ""
    
            case "${DISTRO}" in
                ubuntu|debian|linuxmint|pop)
                    echo -e "${YELLOW}Installing via apt...${NC}"
                    sudo apt update
                    sudo apt install -y tesseract-ocr libtesseract-dev libleptonica-dev
                    ;;
                fedora|rhel|centos|rocky|almalinux)
                    echo -e "${YELLOW}Installing via dnf...${NC}"
                    sudo dnf install -y tesseract tesseract-devel leptonica-devel
                    ;;
                arch|manjaro|endeavouros)
                    echo -e "${YELLOW}Installing via pacman...${NC}"
                    sudo pacman -S --noconfirm tesseract leptonica
                    ;;
                opensuse*)
                    echo -e "${YELLOW}Installing via zypper...${NC}"
                    sudo zypper install -y tesseract-ocr tesseract-ocr-devel leptonica-devel
                    ;;
                *)
                    echo -e "${RED}Unsupported Linux distribution: ${DISTRO}${NC}"
                    echo ""
                    echo "Please install Tesseract manually:"
                    echo "  - Ubuntu/Debian: sudo apt install tesseract-ocr libtesseract-dev libleptonica-dev"
                    echo "  - Fedora/RHEL: sudo dnf install tesseract tesseract-devel leptonica-devel"
                    echo "  - Arch: sudo pacman -S tesseract leptonica"
                    return 1
                    ;;
            esac
            ;;
        *)
            echo -e "${RED}Unsupported OS: ${OS}${NC}"
            echo "For Windows, please use install-tesseract.ps1"
            return 1
            ;;
    esac
    
    # Verify installation
    echo ""
    echo -e "${YELLOW}Verifying installation...${NC}"
    
    if command -v tesseract &> /dev/null; then
        TESSERACT_VERSION=$(tesseract --version 2>&1 | head -n1)
        TESSERACT_PATH=$(which tesseract)
        echo -e "${GREEN}  Tesseract: OK${NC}"
        echo "    Version: ${TESSERACT_VERSION}"
        echo "    Path: ${TESSERACT_PATH}"
    else
        echo -e "${RED}  Tesseract: FAILED${NC}"
        return 1
    fi
    
    # Print success message
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  Installation Complete!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo "Tesseract OCR has been installed system-wide."
    echo "No additional configuration is required - Faria will auto-detect it."
    echo ""
    
    # List available languages
    echo -e "${YELLOW}Available languages:${NC}"
    tesseract --list-langs 2>&1 | tail -n +2 | head -10
    LANG_COUNT=$(tesseract --list-langs 2>&1 | tail -n +2 | wc -l)
    if [ "${LANG_COUNT}" -gt 10 ]; then
        echo "  ... and $((LANG_COUNT - 10)) more"
    fi
    echo ""
}

# ============================================================================
# __install_mupdf() - from install-mupdf.sh
# ============================================================================
__install_mupdf() {
    #
    # Faria MuPDF Installation Script
    # Installs MuPDF for PDF processing
    #
    # Usage: ./install-mupdf.sh [OPTIONS]
    #
    # This script uses system package managers to install MuPDF.
    #
    
    
    # Colors for output
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                echo "Faria MuPDF Installation Script"
                echo ""
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --help, -h         Show this help message"
                echo ""
                echo "This script installs MuPDF using your system's package manager."
                echo "Supported platforms: macOS (Homebrew), Ubuntu/Debian, Fedora/RHEL, Arch Linux"
                return 0
                ;;
            *)
                echo "Unknown option: $1"
                return 1
                ;;
        esac
    done
    
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  Faria MuPDF Installation${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    
    # Detect OS and architecture
    OS="$(uname -s)"
    
    echo -e "${YELLOW}Detecting system...${NC}"
    echo "  OS: ${OS}"
    
    # Check if MuPDF is already installed
    function _local_check_mupdf_installed {
        if command -v mutool &> /dev/null; then
            return 0
        fi
        # Check for library
        if pkg-config --exists mupdf 2>/dev/null; then
            return 0
        fi
        # macOS: check Homebrew
        if [ "${OS}" = "Darwin" ] && brew list mupdf &>/dev/null; then
            return 0
        fi
        return 1
    }
    
    if check_mupdf_installed; then
        if command -v mutool &> /dev/null; then
            MUPDF_VERSION=$(mutool -v 2>&1 | head -n1 || echo "unknown")
        else
            MUPDF_VERSION="installed (version unknown)"
        fi
        echo ""
        echo -e "${GREEN}MuPDF is already installed:${NC}"
        echo "  Version: ${MUPDF_VERSION}"
        echo ""
        read -p "Do you want to reinstall/upgrade? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${GREEN}Skipping installation.${NC}"
            return 0
        fi
    fi
    
    echo ""
    
    # Install based on platform
    case "${OS}" in
        Darwin)
            echo -e "${YELLOW}Installing via Homebrew...${NC}"
            if ! command -v brew &> /dev/null; then
                echo -e "${RED}Error: Homebrew is not installed.${NC}"
                echo "Please install Homebrew first: https://brew.sh"
                return 1
            fi
    
            brew install mupdf
            ;;
        Linux)
            # Detect Linux distribution
            if [ -f /etc/os-release ]; then
                . /etc/os-release
                DISTRO="${ID}"
            elif [ -f /etc/lsb-release ]; then
                . /etc/lsb-release
                DISTRO="${DISTRIB_ID,,}"
            else
                DISTRO="unknown"
            fi
    
            echo "  Distribution: ${DISTRO}"
            echo ""
    
            case "${DISTRO}" in
                ubuntu|debian|linuxmint|pop)
                    echo -e "${YELLOW}Installing via apt...${NC}"
                    sudo apt update
                    sudo apt install -y mupdf mupdf-tools libmupdf-dev
                    ;;
                fedora|rhel|centos|rocky|almalinux)
                    echo -e "${YELLOW}Installing via dnf...${NC}"
                    sudo dnf install -y mupdf mupdf-devel
                    ;;
                arch|manjaro|endeavouros)
                    echo -e "${YELLOW}Installing via pacman...${NC}"
                    sudo pacman -S --noconfirm mupdf mupdf-tools
                    ;;
                opensuse*)
                    echo -e "${YELLOW}Installing via zypper...${NC}"
                    sudo zypper install -y mupdf mupdf-devel
                    ;;
                *)
                    echo -e "${RED}Unsupported Linux distribution: ${DISTRO}${NC}"
                    echo ""
                    echo "Please install MuPDF manually:"
                    echo "  - Ubuntu/Debian: sudo apt install mupdf mupdf-tools libmupdf-dev"
                    echo "  - Fedora/RHEL: sudo dnf install mupdf mupdf-devel"
                    echo "  - Arch: sudo pacman -S mupdf mupdf-tools"
                    return 1
                    ;;
            esac
            ;;
        *)
            echo -e "${RED}Unsupported OS: ${OS}${NC}"
            echo "For Windows, please use install-mupdf.ps1"
            return 1
            ;;
    esac
    
    # Verify installation
    echo ""
    echo -e "${YELLOW}Verifying installation...${NC}"
    
    if command -v mutool &> /dev/null; then
        MUPDF_VERSION=$(mutool -v 2>&1 | head -n1 || echo "installed")
        echo -e "${GREEN}  MuPDF: OK${NC}"
        echo "    Version: ${MUPDF_VERSION}"
    else
        echo -e "${YELLOW}  MuPDF: mutool not in PATH${NC}"
        echo "    Library may still be available for linking"
    fi
    
    # Print success message
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  Installation Complete!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo "MuPDF has been installed system-wide."
    echo "No additional configuration is required - Faria will auto-detect it."
    echo ""
}

# ============================================================================
# __install_onnxruntime() - from install-onnxruntime.sh
# ============================================================================
__install_onnxruntime() {
    #
    # Faria ONNX Runtime Installation Script
    # Downloads and installs ONNX Runtime with CoreML support (macOS) or CUDA support (Linux)
    #
    # Usage: ./install-onnxruntime.sh [OPTIONS]
    #
    # IMPORTANT: Do NOT use Homebrew on macOS - the Homebrew version lacks CoreML/Neural Engine support.
    # This script downloads the official release which includes CoreML execution provider.
    #
    
    
    # Configuration
    ONNXRUNTIME_VERSION="1.22.0"
    
    # Colors for output
    
    # Default install directory
    INSTALL_DIR="${HOME}/.faria"
    ENABLE_GPU=false
    SYSTEM_INSTALL=false
    
    # Save original args before parsing so the root-check error can suggest a correct re-run command
    ORIG_ARGS=("$@")
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --install-dir)
                INSTALL_DIR="$2"
                shift 2
                ;;
            --gpu)
                ENABLE_GPU=true
                shift
                ;;
            --system)
                SYSTEM_INSTALL=true
                shift
                ;;
            --help|-h)
                echo "Faria ONNX Runtime Installation Script"
                echo ""
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --install-dir DIR  Install to DIR (default: ~/.faria)"
                echo "  --gpu              Install GPU/CUDA version (Linux/Windows only)"
                echo "  --system           Install to /usr/local with headers (for Docker/CGO builds)"
                echo "  --help, -h         Show this help message"
                echo ""
                echo "IMPORTANT: This script downloads ONNX Runtime from GitHub releases,"
                echo "NOT from Homebrew. The Homebrew version lacks CoreML/Neural Engine support."
                return 0
                ;;
            *)
                echo "Unknown option: $1"
                return 1
                ;;
        esac
    done
    
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  Faria ONNX Runtime Installation${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    
    # Detect OS and architecture
    OS="$(uname -s)"
    ARCH="$(uname -m)"
    
    echo -e "${YELLOW}Detecting system...${NC}"
    echo "  OS: ${OS}"
    echo "  Architecture: ${ARCH}"
    echo "  GPU enabled: ${ENABLE_GPU}"
    
    # --system is only supported on Linux (requires ldconfig and .so convention)
    if [ "${SYSTEM_INSTALL}" = true ] && [ "${OS}" != "Linux" ]; then
        echo -e "${RED}Error: --system is only supported on Linux.${NC}"
        echo "  Use the default user install on macOS/Windows."
        return 1
    fi
    
    # --system writes to /usr/local and runs ldconfig — both require root.
    # sudo is intentionally NOT used here: --system is designed for Docker/CI
    # environments where the container already runs as root, and sudo is often
    # absent in minimal base images. Non-Docker users who pass --system on a
    # regular Linux host must invoke the script with sudo themselves.
    # The default (non-system) install path writes only to ~/.faria and never
    # requires elevated privileges.
    if [ "${SYSTEM_INSTALL}" = true ] && [ "$(id -u)" -ne 0 ]; then
        echo -e "${RED}Error: --system requires root privileges.${NC}"
        echo "  Inside Docker this is automatic. On a regular host, re-run as:"
        echo "    sudo \"$0\" ${ORIG_ARGS[*]}"
        return 1
    fi
    
    # Determine ONNX Runtime release asset name
    case "${OS}" in
        Darwin)
            case "${ARCH}" in
                arm64)
                    ONNX_ASSET="onnxruntime-osx-arm64-${ONNXRUNTIME_VERSION}.tgz"
                    LIB_NAME="libonnxruntime.dylib"
                    ;;
                x86_64)
                    ONNX_ASSET="onnxruntime-osx-x86_64-${ONNXRUNTIME_VERSION}.tgz"
                    LIB_NAME="libonnxruntime.dylib"
                    ;;
                *)
                    echo -e "${RED}Unsupported architecture: ${ARCH}${NC}"
                    return 1
                    ;;
            esac
            if [ "${ENABLE_GPU}" = true ]; then
                echo -e "${YELLOW}Note: GPU flag ignored on macOS - CoreML acceleration is automatic${NC}"
            fi
            ;;
        Linux)
            case "${ARCH}" in
                x86_64)
                    if [ "${ENABLE_GPU}" = true ]; then
                        ONNX_ASSET="onnxruntime-linux-x64-gpu-${ONNXRUNTIME_VERSION}.tgz"
                    else
                        ONNX_ASSET="onnxruntime-linux-x64-${ONNXRUNTIME_VERSION}.tgz"
                    fi
                    LIB_NAME="libonnxruntime.so"
                    ;;
                aarch64)
                    if [ "${ENABLE_GPU}" = true ]; then
                        echo -e "${YELLOW}Warning: GPU version not available for ARM64 Linux, using CPU version${NC}"
                    fi
                    ONNX_ASSET="onnxruntime-linux-aarch64-${ONNXRUNTIME_VERSION}.tgz"
                    LIB_NAME="libonnxruntime.so"
                    ;;
                *)
                    echo -e "${RED}Unsupported architecture: ${ARCH}${NC}"
                    return 1
                    ;;
            esac
            ;;
        *)
            echo -e "${RED}Unsupported OS: ${OS}${NC}"
            echo "For Windows, please use install-onnxruntime.ps1"
            return 1
            ;;
    esac
    
    ONNX_URL="https://github.com/microsoft/onnxruntime/releases/download/v${ONNXRUNTIME_VERSION}/${ONNX_ASSET}"
    
    echo ""
    echo -e "${YELLOW}Installation configuration:${NC}"
    echo "  Install directory: ${INSTALL_DIR}"
    echo "  ONNX Runtime version: ${ONNXRUNTIME_VERSION}"
    echo "  Asset: ${ONNX_ASSET}"
    echo ""
    
    # Check if already installed (skipped in --system mode)
    LIB_PATH="${INSTALL_DIR}/lib/onnxruntime/${LIB_NAME}"
    if [ "${SYSTEM_INSTALL}" = false ] && [ -f "${LIB_PATH}" ]; then
        echo -e "${YELLOW}ONNX Runtime already installed at: ${LIB_PATH}${NC}"
        read -p "Do you want to reinstall? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${GREEN}Skipping installation.${NC}"
            return 0
        fi
    fi
    
    # Create directories
    echo -e "${YELLOW}Creating directories...${NC}"
    if [ "${SYSTEM_INSTALL}" = false ]; then
        mkdir -p "${INSTALL_DIR}/lib/onnxruntime"
    fi
    
    # Download ONNX Runtime
    TEMP_DIR=$(mktemp -d)
    trap "rm -rf ${TEMP_DIR}" EXIT
    
    echo ""
    echo -e "${YELLOW}Downloading ONNX Runtime...${NC}"
    echo "  URL: ${ONNX_URL}"
    
    if command -v curl &> /dev/null; then
        curl -L --progress-bar -o "${TEMP_DIR}/onnxruntime.tgz" "${ONNX_URL}"
    elif command -v wget &> /dev/null; then
        wget -q --show-progress -O "${TEMP_DIR}/onnxruntime.tgz" "${ONNX_URL}"
    else
        echo -e "${RED}Error: Neither curl nor wget found. Please install one of them.${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}Extracting ONNX Runtime...${NC}"
    tar -xzf "${TEMP_DIR}/onnxruntime.tgz" -C "${TEMP_DIR}"
    
    # Find and copy library files
    EXTRACTED_DIR=$(find "${TEMP_DIR}" -maxdepth 1 -type d -name "onnxruntime-*" | head -1)
    if [ -z "${EXTRACTED_DIR}" ]; then
        echo -e "${RED}Error: Could not find extracted ONNX Runtime directory${NC}"
        return 1
    fi
    
    if [ "${SYSTEM_INSTALL}" = true ]; then
        # System-wide install: lib/ + include/ to /usr/local for CGO builds
        echo -e "${YELLOW}Installing to /usr/local (system mode)...${NC}"
        # Copy all libraries preserving symlinks (includes GPU provider shared objects)
        mkdir -p /usr/local/lib
        cp -a "${EXTRACTED_DIR}/lib/." /usr/local/lib/
        # Ensure a stable unversioned symlink for CGO (-lonnxruntime) and verify.sh
        ln -sf "libonnxruntime.so.${ONNXRUNTIME_VERSION}" /usr/local/lib/libonnxruntime.so
        # The tarball layout is include/onnxruntime/core/... so copy the inner
        # onnxruntime/ dir to match CGO_CFLAGS=-I/usr/local/include/onnxruntime
        if [ -d "${EXTRACTED_DIR}/include/onnxruntime" ]; then
            mkdir -p /usr/local/include/onnxruntime
            cp -r "${EXTRACTED_DIR}/include/onnxruntime/"* /usr/local/include/onnxruntime/
        fi
        echo -e "${YELLOW}Running ldconfig...${NC}"
        ldconfig
    else
        # User install: lib/ only to ~/.faria/lib/onnxruntime/
        echo -e "${YELLOW}Installing library files...${NC}"
        cp -r "${EXTRACTED_DIR}/lib/"* "${INSTALL_DIR}/lib/onnxruntime/"
    fi
    
    # Verify installation
    echo ""
    echo -e "${YELLOW}Verifying installation...${NC}"
    
    if [ "${SYSTEM_INSTALL}" = true ]; then
        VERIFY_PATH="/usr/local/lib/${LIB_NAME}"
    else
        VERIFY_PATH="${LIB_PATH}"
    fi
    
    if [ -f "${VERIFY_PATH}" ]; then
        LIB_SIZE=$(du -h "${VERIFY_PATH}" | cut -f1)
        echo -e "${GREEN}  ${LIB_NAME}: OK (${LIB_SIZE})${NC}"
    else
        echo -e "${RED}  ${LIB_NAME}: FAILED (expected at ${VERIFY_PATH})${NC}"
        return 1
    fi
    
    # Print success message and instructions
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  Installation Complete!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    if [ "${SYSTEM_INSTALL}" = true ]; then
        INSTALLED_LIB_PATH="/usr/local/lib/${LIB_NAME}"
    else
        INSTALLED_LIB_PATH="${INSTALL_DIR}/lib/onnxruntime/${LIB_NAME}"
    fi
    
    echo "Installed files:"
    echo "  ${INSTALLED_LIB_PATH}"
    echo ""
    echo -e "${YELLOW}Configuration Options:${NC}"
    echo ""
    echo "Option 1: Environment variable (recommended)"
    echo "  Add this to your shell profile (~/.bashrc, ~/.zshrc, etc.):"
    echo ""
    echo "    export FARIA_ONNXRUNTIME_PATH=\"${INSTALLED_LIB_PATH}\""
    echo ""
    echo "Option 2: Auto-detection"
    echo "  Faria will automatically detect files in ~/.faria/ (no action needed)"
    echo ""
    echo "Option 3: Manual configuration in code"
    echo "  config.Runtime.ONNXLibraryPath = \"${INSTALLED_LIB_PATH}\""
    echo ""
    
    if [ "${OS}" = "Darwin" ]; then
        echo -e "${BLUE}Note: CoreML/Neural Engine acceleration is enabled automatically on macOS.${NC}"
    elif [ "${ENABLE_GPU}" = true ]; then
        echo -e "${BLUE}Note: CUDA GPU acceleration is enabled. Ensure CUDA Toolkit is installed.${NC}"
    fi
    echo ""
}

# ============================================================================
# __install_models() - from install-models.sh
# ============================================================================
__install_models() {
    #
    # Faria ML Models Installation Script
    # Downloads and installs CLIP, DETR, and Nemotron ONNX models.
    #
    # CLIP     — always downloaded from Qdrant/clip-ViT-B-32-vision (HuggingFace)
    # DETR     — with --system: downloaded from pavan-synkrato360/faria-models (HF)
    #            without --system: exported via Python/PyTorch (local dev workflow)
    # Nemotron — with --system: downloaded from pavan-synkrato360/faria-models (HF)
    #            without --system: cloned from HuggingFace and exported via Python
    #
    # Usage: ./install-models.sh [OPTIONS]
    #
    # Prerequisites (only required without --system):
    #   - Python 3.8+
    #   - Git with Git LFS (for Nemotron)
    #
    
    
    # Colors for output
    
    # Check if running in interactive mode (not piped)
    function _local_is_interactive { [ -t 0 ]; }
    
    # Default install directory
    INSTALL_DIR="${HOME}/.faria"
    SKIP_CLIP=false
    SKIP_DETR=false
    SKIP_NEMOTRON=false
    KEEP_VENV=false
    SYSTEM_INSTALL=false
    
    # Get script directory (where this script is located)
    # The repo root is the parent of scripts/
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --install-dir)
                INSTALL_DIR="$2"
                shift 2
                ;;
            --skip-clip)
                SKIP_CLIP=true
                shift
                ;;
            --skip-detr)
                SKIP_DETR=true
                shift
                ;;
            --skip-nemotron)
                SKIP_NEMOTRON=true
                shift
                ;;
            --keep-venv)
                KEEP_VENV=true
                shift
                ;;
            --system)
                SYSTEM_INSTALL=true
                shift
                ;;
            --help|-h)
                echo "Faria ML Models Installation Script"
                echo ""
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --install-dir DIR  Install to DIR (default: ~/.faria)"
                echo "  --system           Download models directly from HuggingFace (no Python required)"
                echo "                     Suitable for Docker/CI builds and system-wide installs"
                echo "  --skip-clip        Skip CLIP visual model download"
                echo "  --skip-detr        Skip DETR model installation"
                echo "  --skip-nemotron    Skip Nemotron model installation"
                echo "  --keep-venv        Keep Python virtual environment after installation (local only)"
                echo "  --help, -h         Show this help message"
                echo ""
                echo "Prerequisites:"
                echo "  --system mode: curl or wget"
                echo "  local mode:    Python 3.8+, Git with Git LFS (for Nemotron)"
                return 0
                ;;
            *)
                echo "Unknown option: $1"
                return 1
                ;;
        esac
    done
    
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  Faria ML Models Installation${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    
    # Detect OS
    OS="$(uname -s)"
    
    echo -e "${YELLOW}Detecting system...${NC}"
    echo "  OS: ${OS}"
    if [ "${SYSTEM_INSTALL}" = false ]; then
        echo "  Repository: ${REPO_DIR}"
    fi
    echo ""
    
    echo ""
    echo -e "${YELLOW}Installation configuration:${NC}"
    echo "  Install directory: ${INSTALL_DIR}"
    echo "  Mode:     $([ "${SYSTEM_INSTALL}" = true ] && echo "system (HuggingFace direct download)" || echo "local (Python export)")"
    echo "  CLIP:     $([ "${SKIP_CLIP}" = true ] && echo "skip" || echo "install")"
    echo "  DETR:     $([ "${SKIP_DETR}" = true ] && echo "skip" || echo "install")"
    echo "  Nemotron: $([ "${SKIP_NEMOTRON}" = true ] && echo "skip" || echo "install")"
    echo ""
    
    # Create model directory
    mkdir -p "${INSTALL_DIR}/models"
    
    # ============================================================================
    # Prerequisites check (local mode only)
    # ============================================================================
    if [ "${SYSTEM_INSTALL}" = false ]; then
        echo -e "${YELLOW}Checking prerequisites...${NC}"
    
        # Check Python (requires 3.12.x for onnxruntime compatibility)
        __setup_python
    
        if [ -z "${PYTHON_CMD}" ]; then
            echo -e "${RED}Error: Python 3.12 setup failed${NC}"
            return 1
        fi
    
        PYTHON_VERSION=$($PYTHON_CMD --version 2>&1 | cut -d' ' -f2)
    
        # Check Git
        if ! command -v git &> /dev/null; then
            echo -e "${RED}Error: Git not found. Please install Git.${NC}"
            return 1
        fi
        echo -e "${GREEN}  Git: $(git --version | cut -d' ' -f3)${NC}"
    
        # Check Git LFS (required for Nemotron in local mode)
        if [ "${SKIP_NEMOTRON}" = false ]; then
            if ! command -v git-lfs &> /dev/null; then
                echo -e "${RED}Error: Git LFS not found. Please install Git LFS.${NC}"
                echo ""
                echo "Installation:"
                echo "  macOS: brew install git-lfs"
                echo "  Ubuntu/Debian: sudo apt install git-lfs"
                echo "  Then run: git lfs install"
                return 1
            fi
            echo -e "${GREEN}  Git LFS: installed${NC}"
        fi
    
        # Create temp directory for work
        WORK_DIR=$(mktemp -d)
        VENV_DIR="${WORK_DIR}/venv"
    
        function _local_cleanup {
            if [ "${KEEP_VENV}" = false ]; then
                echo -e "${YELLOW}Cleaning up temporary files...${NC}"
                rm -rf "${WORK_DIR}"
            else
                echo -e "${YELLOW}Keeping virtual environment at: ${VENV_DIR}${NC}"
            fi
        }
        trap _local_cleanup EXIT
    
        # Create virtual environment
        echo -e "${YELLOW}Creating Python virtual environment...${NC}"
        $PYTHON_CMD -m venv "${VENV_DIR}"
        source "${VENV_DIR}/bin/activate"
    
        # Upgrade pip
        echo -e "${YELLOW}Upgrading pip...${NC}"
        pip install --upgrade pip -q
    fi
    
    # ============================================================================
    # Helper: download a model from HuggingFace (system mode)
    # ============================================================================
    _hf_download() {
        local label="$1"
        local url="$2"
        local dest="$3"
    
        echo -e "${YELLOW}Downloading ${label} from HuggingFace...${NC}"
        echo "  URL: ${url}"
    
        if command -v curl &> /dev/null; then
            if [ -n "${HF_TOKEN}" ]; then
                curl -fSL -H "Authorization: Bearer ${HF_TOKEN}" "${url}" -o "${dest}"
            else
                curl -fSL "${url}" -o "${dest}"
            fi
        elif command -v wget &> /dev/null; then
            if [ -n "${HF_TOKEN}" ]; then
                wget -q --header="Authorization: Bearer ${HF_TOKEN}" "${url}" -O "${dest}"
            else
                wget -q "${url}" -O "${dest}"
            fi
        else
            echo -e "${RED}Error: Neither curl nor wget found.${NC}"
            return 1
        fi
    
        if [ -f "${dest}" ]; then
            local size
            size=$(du -h "${dest}" | cut -f1)
            echo -e "${GREEN}  $(basename "${dest}"): OK (${size})${NC}"
        else
            echo -e "${RED}  $(basename "${dest}"): FAILED${NC}"
            return 1
        fi
    }
    
    # ============================================================================
    # Download CLIP Visual Model (always direct download — no Python export exists)
    # ============================================================================
    if [ "${SKIP_CLIP}" = false ]; then
        echo ""
        echo -e "${BLUE}----------------------------------------${NC}"
        echo -e "${BLUE}  Downloading CLIP Visual Model${NC}"
        echo -e "${BLUE}----------------------------------------${NC}"
        echo ""
    
        CLIP_MODEL_PATH="${INSTALL_DIR}/models/clip_visual.onnx"
    
        if [ -f "${CLIP_MODEL_PATH}" ]; then
            echo -e "${YELLOW}CLIP model already exists at: ${CLIP_MODEL_PATH}${NC}"
            if is_interactive; then
                read -p "Do you want to redownload? (y/N): " -n 1 -r
                echo
                if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                    echo -e "${GREEN}Skipping CLIP download.${NC}"
                    SKIP_CLIP=true
                fi
            else
                echo -e "${YELLOW}Non-interactive mode: skipping redownload.${NC}"
                SKIP_CLIP=true
            fi
        fi
    
        if [ "${SKIP_CLIP}" = false ]; then
            _hf_download \
                "CLIP model" \
                "https://huggingface.co/Qdrant/clip-ViT-B-32-vision/resolve/main/model.onnx" \
                "${CLIP_MODEL_PATH}"
        fi
    fi
    
    # ============================================================================
    # Install DETR Model
    # ============================================================================
    if [ "${SKIP_DETR}" = false ]; then
        echo ""
        echo -e "${BLUE}----------------------------------------${NC}"
        echo -e "${BLUE}  Installing DETR Model${NC}"
        echo -e "${BLUE}----------------------------------------${NC}"
        echo ""
    
        DETR_MODEL_PATH="${INSTALL_DIR}/models/detr_layout_detection.onnx"
    
        # Check if already exists
        if [ -f "${DETR_MODEL_PATH}" ]; then
            echo -e "${YELLOW}DETR model already exists at: ${DETR_MODEL_PATH}${NC}"
            if is_interactive; then
                read -p "Do you want to reinstall? (y/N): " -n 1 -r
                echo
                if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                    echo -e "${GREEN}Skipping DETR installation.${NC}"
                    SKIP_DETR=true
                fi
            else
                echo -e "${YELLOW}Non-interactive mode: skipping reinstall.${NC}"
                SKIP_DETR=true
            fi
        fi
    
        if [ "${SKIP_DETR}" = false ]; then
            if [ "${SYSTEM_INSTALL}" = true ]; then
                # System/Docker mode: download pre-built ONNX from HuggingFace
                _hf_download \
                    "DETR model" \
                    "https://huggingface.co/pavan-synkrato360/faria-models/resolve/main/detr_layout_detection.onnx" \
                    "${DETR_MODEL_PATH}"
            else
                # Local dev mode: export from PyTorch using export script
                echo -e "${YELLOW}Installing DETR dependencies...${NC}"
                pip install -r "${MODELS_CACHE_DIR}/requirements-detr.txt" -q
    
                echo -e "${YELLOW}Exporting DETR model to ONNX...${NC}"
                echo "  This may take a few minutes on first run (downloading model)..."
    
                DETR_EXPORT_SCRIPT="${MODELS_CACHE_DIR}/export_detr_layout_onnx.py"
    
                if [ ! -f "${DETR_EXPORT_SCRIPT}" ]; then
                    echo -e "${RED}Error: DETR export script not found at: ${DETR_EXPORT_SCRIPT}${NC}"
                    return 1
                fi
    
                cd "${WORK_DIR}"
                python "${DETR_EXPORT_SCRIPT}" --output "${DETR_MODEL_PATH}"
    
                if [ -f "${DETR_MODEL_PATH}" ]; then
                    DETR_SIZE=$(du -h "${DETR_MODEL_PATH}" | cut -f1)
                    echo -e "${GREEN}  DETR model installed: ${DETR_MODEL_PATH} (${DETR_SIZE})${NC}"
                else
                    echo -e "${RED}Error: DETR ONNX file not found after export${NC}"
                    echo "  Expected output: ${DETR_MODEL_PATH}"
                    return 1
                fi
            fi
        fi
    fi
    
    # ============================================================================
    # Install Nemotron Model
    # ============================================================================
    if [ "${SKIP_NEMOTRON}" = false ]; then
        echo ""
        echo -e "${BLUE}----------------------------------------${NC}"
        echo -e "${BLUE}  Installing Nemotron Model${NC}"
        echo -e "${BLUE}----------------------------------------${NC}"
        echo ""
    
        NEMOTRON_MODEL_PATH="${INSTALL_DIR}/models/nemotron_table_structure.onnx"
    
        # Check if already exists
        if [ -f "${NEMOTRON_MODEL_PATH}" ]; then
            echo -e "${YELLOW}Nemotron model already exists at: ${NEMOTRON_MODEL_PATH}${NC}"
            if is_interactive; then
                read -p "Do you want to reinstall? (y/N): " -n 1 -r
                echo
                if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                    echo -e "${GREEN}Skipping Nemotron installation.${NC}"
                    SKIP_NEMOTRON=true
                fi
            else
                echo -e "${YELLOW}Non-interactive mode: skipping reinstall.${NC}"
                SKIP_NEMOTRON=true
            fi
        fi
    
        if [ "${SKIP_NEMOTRON}" = false ]; then
            if [ "${SYSTEM_INSTALL}" = true ]; then
                # System/Docker mode: download pre-built ONNX from HuggingFace
                _hf_download \
                    "Nemotron model" \
                    "https://huggingface.co/pavan-synkrato360/faria-models/resolve/main/nemotron_table_structure.onnx" \
                    "${NEMOTRON_MODEL_PATH}"
            else
                # Local dev mode: clone from HuggingFace and export via Python
                echo -e "${YELLOW}Cloning Nemotron repository from HuggingFace...${NC}"
                echo "  This may take a while (downloading ~200MB model)..."
    
                NEMOTRON_REPO="${WORK_DIR}/nemotron-table-structure-v1"
    
                cd "${WORK_DIR}"
                git lfs install
                git clone https://huggingface.co/nvidia/nemotron-table-structure-v1 "${NEMOTRON_REPO}"
    
                echo -e "${YELLOW}Installing Nemotron package...${NC}"
                cd "${NEMOTRON_REPO}"
                pip install -r "${MODELS_CACHE_DIR}/requirements-nemotron.txt" -q
                pip install -e . -q
    
                echo -e "${YELLOW}Exporting Nemotron model to ONNX...${NC}"
    
                NEMOTRON_EXPORT_SCRIPT="${MODELS_CACHE_DIR}/export_nemotron_onnx.py"
    
                if [ ! -f "${NEMOTRON_EXPORT_SCRIPT}" ]; then
                    echo -e "${RED}Error: Nemotron export script not found at: ${NEMOTRON_EXPORT_SCRIPT}${NC}"
                    return 1
                fi
    
                cd "${WORK_DIR}"
                python "${NEMOTRON_EXPORT_SCRIPT}" --output "${NEMOTRON_MODEL_PATH}"
    
                if [ -f "${NEMOTRON_MODEL_PATH}" ]; then
                    NEMOTRON_SIZE=$(du -h "${NEMOTRON_MODEL_PATH}" | cut -f1)
                    echo -e "${GREEN}  Nemotron model installed: ${NEMOTRON_MODEL_PATH} (${NEMOTRON_SIZE})${NC}"
                else
                    echo -e "${RED}Error: Nemotron ONNX file not found after export${NC}"
                    echo "  Expected output: ${NEMOTRON_MODEL_PATH}"
                    return 1
                fi
            fi
        fi
    fi
    
    # Deactivate virtual environment (local mode only)
    if [ "${SYSTEM_INSTALL}" = false ] && command -v deactivate &> /dev/null 2>&1; then
        deactivate
    fi
    
    # Verify installation
    echo ""
    echo -e "${YELLOW}Verifying installation...${NC}"
    
    if [ "${SKIP_CLIP}" = false ] && [ -f "${INSTALL_DIR}/models/clip_visual.onnx" ]; then
        CLIP_SIZE=$(du -h "${INSTALL_DIR}/models/clip_visual.onnx" | cut -f1)
        echo -e "${GREEN}  CLIP: OK (${CLIP_SIZE})${NC}"
    elif [ "${SKIP_CLIP}" = true ]; then
        echo -e "${YELLOW}  CLIP: skipped${NC}"
    else
        echo -e "${RED}  CLIP: FAILED${NC}"
    fi
    
    if [ "${SKIP_DETR}" = false ] && [ -f "${INSTALL_DIR}/models/detr_layout_detection.onnx" ]; then
        DETR_SIZE=$(du -h "${INSTALL_DIR}/models/detr_layout_detection.onnx" | cut -f1)
        echo -e "${GREEN}  DETR: OK (${DETR_SIZE})${NC}"
    elif [ "${SKIP_DETR}" = true ]; then
        echo -e "${YELLOW}  DETR: skipped${NC}"
    else
        echo -e "${RED}  DETR: FAILED${NC}"
    fi
    
    if [ "${SKIP_NEMOTRON}" = false ] && [ -f "${INSTALL_DIR}/models/nemotron_table_structure.onnx" ]; then
        NEMOTRON_SIZE=$(du -h "${INSTALL_DIR}/models/nemotron_table_structure.onnx" | cut -f1)
        echo -e "${GREEN}  Nemotron: OK (${NEMOTRON_SIZE})${NC}"
    elif [ "${SKIP_NEMOTRON}" = true ]; then
        echo -e "${YELLOW}  Nemotron: skipped${NC}"
    else
        echo -e "${RED}  Nemotron: FAILED${NC}"
    fi
    
    # Print success message
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  Installation Complete!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo "Installed models:"
    [ -f "${INSTALL_DIR}/models/clip_visual.onnx" ] && echo "  ${INSTALL_DIR}/models/clip_visual.onnx"
    [ -f "${INSTALL_DIR}/models/detr_layout_detection.onnx" ] && echo "  ${INSTALL_DIR}/models/detr_layout_detection.onnx"
    [ -f "${INSTALL_DIR}/models/nemotron_table_structure.onnx" ] && echo "  ${INSTALL_DIR}/models/nemotron_table_structure.onnx"
    echo ""
    echo -e "${YELLOW}Configuration Options:${NC}"
    echo ""
    echo "Option 1: Environment variables (recommended)"
    echo "  Add these to your shell profile (~/.bashrc, ~/.zshrc, etc.):"
    echo ""
    echo "    export FARIA_CLIP_MODEL_PATH=\"${INSTALL_DIR}/models/clip_visual.onnx\""
    echo "    export FARIA_DETR_MODEL_PATH=\"${INSTALL_DIR}/models/detr_layout_detection.onnx\""
    echo "    export FARIA_NEMOTRON_MODEL_PATH=\"${INSTALL_DIR}/models/nemotron_table_structure.onnx\""
    echo ""
    echo "Option 2: Auto-detection"
    echo "  Faria will automatically detect files in ~/.faria/ (no action needed)"
    echo ""
}

# ============================================================================
# __install_slm() - from install-slm.sh
# ============================================================================
__install_slm() {
    #
    # Faria SLM Installation Script
    # Downloads and installs llama-cli and Qwen model for SLM features
    #
    # Usage: ./install-slm.sh [--install-dir DIR]
    #
    # Default install location: ~/.faria/
    #
    
    
    # Configuration
    LLAMA_CPP_VERSION="b4549"
    QWEN_MODEL="qwen2.5-0.5b-instruct-q8_0.gguf"
    QWEN_MODEL_URL="https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/${QWEN_MODEL}"
    
    # Colors for output
    
    # Default install directory
    INSTALL_DIR="${HOME}/.faria"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --install-dir)
                INSTALL_DIR="$2"
                shift 2
                ;;
            --help|-h)
                echo "Faria SLM Installation Script"
                echo ""
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --install-dir DIR  Install to DIR (default: ~/.faria)"
                echo "  --help, -h         Show this help message"
                return 0
                ;;
            *)
                echo "Unknown option: $1"
                return 1
                ;;
        esac
    done
    
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  Faria SLM Installation Script${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    
    # Detect OS and architecture
    OS="$(uname -s)"
    ARCH="$(uname -m)"
    
    echo -e "${YELLOW}Detecting system...${NC}"
    echo "  OS: ${OS}"
    echo "  Architecture: ${ARCH}"
    
    # Determine llama.cpp release asset name
    case "${OS}" in
        Darwin)
            case "${ARCH}" in
                arm64)
                    LLAMA_ASSET="llama-${LLAMA_CPP_VERSION}-bin-macos-arm64.zip"
                    ;;
                x86_64)
                    LLAMA_ASSET="llama-${LLAMA_CPP_VERSION}-bin-macos-x64.zip"
                    ;;
                *)
                    echo -e "${RED}Unsupported architecture: ${ARCH}${NC}"
                    return 1
                    ;;
            esac
            ;;
        Linux)
            case "${ARCH}" in
                x86_64)
                    LLAMA_ASSET="llama-${LLAMA_CPP_VERSION}-bin-ubuntu-x64.zip"
                    ;;
                aarch64)
                    LLAMA_ASSET="llama-${LLAMA_CPP_VERSION}-bin-ubuntu-arm64.zip"
                    ;;
                *)
                    echo -e "${RED}Unsupported architecture: ${ARCH}${NC}"
                    return 1
                    ;;
            esac
            ;;
        *)
            echo -e "${RED}Unsupported OS: ${OS}${NC}"
            echo "For Windows, please use install-slm.ps1"
            return 1
            ;;
    esac
    
    LLAMA_URL="https://github.com/ggerganov/llama.cpp/releases/download/${LLAMA_CPP_VERSION}/${LLAMA_ASSET}"
    
    echo ""
    echo -e "${YELLOW}Installation configuration:${NC}"
    echo "  Install directory: ${INSTALL_DIR}"
    echo "  llama.cpp version: ${LLAMA_CPP_VERSION}"
    echo "  Model: ${QWEN_MODEL}"
    echo ""
    
    # Create directories
    echo -e "${YELLOW}Creating directories...${NC}"
    mkdir -p "${INSTALL_DIR}/bin"
    mkdir -p "${INSTALL_DIR}/models"
    
    # Download llama.cpp
    TEMP_DIR=$(mktemp -d)
    trap "rm -rf ${TEMP_DIR}" EXIT
    
    echo ""
    echo -e "${YELLOW}Downloading llama.cpp...${NC}"
    echo "  URL: ${LLAMA_URL}"
    
    if command -v curl &> /dev/null; then
        curl -L --progress-bar -o "${TEMP_DIR}/llama.zip" "${LLAMA_URL}"
    elif command -v wget &> /dev/null; then
        wget -q --show-progress -O "${TEMP_DIR}/llama.zip" "${LLAMA_URL}"
    else
        echo -e "${RED}Error: Neither curl nor wget found. Please install one of them.${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}Extracting llama.cpp...${NC}"
    unzip -q "${TEMP_DIR}/llama.zip" -d "${TEMP_DIR}/llama"
    
    # Find and copy llama-cli
    LLAMA_CLI=$(find "${TEMP_DIR}/llama" -name "llama-cli" -type f | head -1)
    if [ -z "${LLAMA_CLI}" ]; then
        echo -e "${RED}Error: llama-cli not found in archive${NC}"
        return 1
    fi
    
    cp "${LLAMA_CLI}" "${INSTALL_DIR}/bin/llama-cli"
    chmod +x "${INSTALL_DIR}/bin/llama-cli"
    echo -e "${GREEN}  Installed: ${INSTALL_DIR}/bin/llama-cli${NC}"
    
    # Download Qwen model
    echo ""
    echo -e "${YELLOW}Downloading Qwen model (this may take a while)...${NC}"
    echo "  URL: ${QWEN_MODEL_URL}"
    echo "  Size: ~530MB"
    
    MODEL_PATH="${INSTALL_DIR}/models/${QWEN_MODEL}"
    
    if [ -f "${MODEL_PATH}" ]; then
        echo -e "${YELLOW}  Model already exists, skipping download${NC}"
    else
        if command -v curl &> /dev/null; then
            curl -L --progress-bar -o "${MODEL_PATH}" "${QWEN_MODEL_URL}"
        elif command -v wget &> /dev/null; then
            wget -q --show-progress -O "${MODEL_PATH}" "${QWEN_MODEL_URL}"
        fi
        echo -e "${GREEN}  Downloaded: ${MODEL_PATH}${NC}"
    fi
    
    # Verify installation
    echo ""
    echo -e "${YELLOW}Verifying installation...${NC}"
    
    if [ -x "${INSTALL_DIR}/bin/llama-cli" ]; then
        echo -e "${GREEN}  llama-cli: OK${NC}"
    else
        echo -e "${RED}  llama-cli: FAILED${NC}"
        return 1
    fi
    
    if [ -f "${MODEL_PATH}" ]; then
        MODEL_SIZE=$(du -h "${MODEL_PATH}" | cut -f1)
        echo -e "${GREEN}  Model: OK (${MODEL_SIZE})${NC}"
    else
        echo -e "${RED}  Model: FAILED${NC}"
        return 1
    fi
    
    # Print success message and instructions
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  Installation Complete!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo "Installed files:"
    echo "  ${INSTALL_DIR}/bin/llama-cli"
    echo "  ${INSTALL_DIR}/models/${QWEN_MODEL}"
    echo ""
    echo -e "${YELLOW}Configuration Options:${NC}"
    echo ""
    echo "Option 1: Environment variables (recommended)"
    echo "  Add these to your shell profile (~/.bashrc, ~/.zshrc, etc.):"
    echo ""
    echo "    export FARIA_LLAMA_CLI_PATH=\"${INSTALL_DIR}/bin/llama-cli\""
    echo "    export FARIA_SLM_MODEL_PATH=\"${INSTALL_DIR}/models/${QWEN_MODEL}\""
    echo ""
    echo "Option 2: Auto-detection"
    echo "  Faria will automatically detect files in ~/.faria/ (no action needed)"
    echo ""
    echo "Option 3: Manual configuration in code"
    echo "  config.Document.SLMConfig = &faria.SLMConfig{"
    echo "      LlamaCLIPath: \"${INSTALL_DIR}/bin/llama-cli\","
    echo "      ModelPath:    \"${INSTALL_DIR}/models/${QWEN_MODEL}\","
    echo "  }"
    echo ""
}

# ============================================================================
# __verify_installation() - from verify.sh
# ============================================================================
__verify_installation() {
    #
    # Faria Installation Verification Script
    # Checks all required and optional components
    # Reads version requirements from versions.json
    #
    # Usage: ./verify.sh [OPTIONS]
    #
    
    
    # Colors for output
    
    # Symbols
    CHECK="${GREEN}✓${NC}"
    CROSS="${RED}✗${NC}"
    WARN="${YELLOW}!${NC}"
    
    # Default install directory
    INSTALL_DIR="${HOME}/.faria"
    SYSTEM_INSTALL=false
    
    # Get script directory and config path
    CONFIG_FILE="${SCRIPT_DIR}/../versions.json"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --install-dir)
                INSTALL_DIR="$2"
                shift 2
                ;;
            --system)
                SYSTEM_INSTALL=true
                shift
                ;;
            --help|-h)
                echo "Faria Installation Verification Script"
                echo ""
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --install-dir DIR  Check installation in DIR (default: ~/.faria)"
                echo "  --system           Verify a system-wide install (/usr/local)"
                echo "  --help, -h         Show this help message"
                return 0
                ;;
            *)
                echo "Unknown option: $1"
                return 1
                ;;
        esac
    done
    
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  Faria Installation Verification${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    
    # Detect OS
    OS="$(uname -s)"
    ARCH="$(uname -m)"
    
    echo -e "${YELLOW}System Information:${NC}"
    echo "  OS: ${OS}"
    echo "  Architecture: ${ARCH}"
    echo "  Install directory: ${INSTALL_DIR}"
    echo ""
    
    # Track overall status
    ALL_REQUIRED_OK=true
    MISSING_COMPONENTS=""
    
    # ============================================================================
    # Version checking functions
    # ============================================================================
    
    # Get minimum version from config
    function _local_get_min_version {
        local dep=$1
        if [ -f "${CONFIG_FILE}" ] && command -v jq &> /dev/null; then
            jq -r ".minimum.${dep} // \"0.0.0\"" "${CONFIG_FILE}"
        else
            echo "0.0.0"
        fi
    }
    
    # Compare versions (returns 0 if current >= min)
    function _local_version_gte {
        local current=$1
        local min=$2
        if [[ "$(printf '%s\n' "$min" "$current" | sort -V | head -n1)" == "$min" ]]; then
            return 0
        else
            return 1
        fi
    }
    
    # Check version and print result
    function _local_check_version {
        local name=$1
        local current=$2
        local min=$(get_min_version "$name")
    
        if [ "$current" = "0.0.0" ] || [ -z "$current" ]; then
            return 1
        fi
    
        if version_gte "$current" "$min"; then
            echo -e "  ${CHECK} ${name}: ${current} (min: ${min})"
            return 0
        else
            echo -e "  ${CROSS} ${name}: ${current} is below minimum ${min}"
            return 1
        fi
    }
    
    echo -e "${YELLOW}Checking dependency versions...${NC}"
    echo ""
    
    # ============================================================================
    # Check ONNX Runtime
    # ============================================================================
    echo -e "${BLUE}ONNX Runtime:${NC}"
    
    # Determine library name based on OS
    case "${OS}" in
        Darwin)
            LIB_NAME="libonnxruntime.dylib"
            ;;
        Linux)
            LIB_NAME="libonnxruntime.so"
            ;;
        *)
            LIB_NAME="onnxruntime.dll"
            ;;
    esac
    
    # Check environment variable first
    ONNX_PATH="${FARIA_ONNXRUNTIME_PATH:-}"
    
    if [ "${SYSTEM_INSTALL}" = true ]; then
        # System install: library lands in /usr/local/lib
        if [ -z "${ONNX_PATH}" ] || [ ! -f "${ONNX_PATH}" ]; then
            ONNX_PATH="/usr/local/lib/${LIB_NAME}"
        fi
    else
        # User install: library lands in <install-dir>/lib/onnxruntime
        if [ -z "${ONNX_PATH}" ] || [ ! -f "${ONNX_PATH}" ]; then
            ONNX_PATH="${INSTALL_DIR}/lib/onnxruntime/${LIB_NAME}"
        fi
    fi
    
    if [ -f "${ONNX_PATH}" ]; then
        LIB_SIZE=$(du -h "${ONNX_PATH}" | cut -f1)
        echo -e "  ${CHECK} Found (${LIB_SIZE})"
        echo "     ${ONNX_PATH}"
    else
        echo -e "  ${CROSS} Not found"
        echo "     Expected: ${ONNX_PATH}"
        ALL_REQUIRED_OK=false
        MISSING_COMPONENTS="${MISSING_COMPONENTS}ONNX Runtime, "
    fi
    echo ""
    
    # ============================================================================
    # Check CLIP Model
    # ============================================================================
    echo -e "${BLUE}CLIP Model (Visual Embedding):${NC}"
    
    CLIP_PATH="${FARIA_CLIP_MODEL_PATH:-}"
    if [ -z "${CLIP_PATH}" ] || [ ! -f "${CLIP_PATH}" ]; then
        CLIP_PATH="${INSTALL_DIR}/models/clip_visual.onnx"
    fi
    
    if [ -f "${CLIP_PATH}" ]; then
        MODEL_SIZE=$(du -h "${CLIP_PATH}" | cut -f1)
        echo -e "  ${CHECK} Found (${MODEL_SIZE})"
        echo "     ${CLIP_PATH}"
    else
        echo -e "  ${CROSS} Not found"
        echo "     Expected: ${INSTALL_DIR}/models/clip_visual.onnx"
        ALL_REQUIRED_OK=false
        MISSING_COMPONENTS="${MISSING_COMPONENTS}CLIP Model, "
    fi
    echo ""
    
    # ============================================================================
    # Check DETR Model
    # ============================================================================
    echo -e "${BLUE}DETR Model (Layout Detection):${NC}"
    
    DETR_PATH="${FARIA_DETR_MODEL_PATH:-}"
    if [ -z "${DETR_PATH}" ] || [ ! -f "${DETR_PATH}" ]; then
        DETR_PATH="${INSTALL_DIR}/models/detr_layout_detection.onnx"
    fi
    
    if [ -f "${DETR_PATH}" ]; then
        MODEL_SIZE=$(du -h "${DETR_PATH}" | cut -f1)
        echo -e "  ${CHECK} Found (${MODEL_SIZE})"
        echo "     ${DETR_PATH}"
    else
        echo -e "  ${CROSS} Not found"
        echo "     Expected: ${INSTALL_DIR}/models/detr_layout_detection.onnx"
        ALL_REQUIRED_OK=false
        MISSING_COMPONENTS="${MISSING_COMPONENTS}DETR Model, "
    fi
    echo ""
    
    # ============================================================================
    # Check Nemotron Model
    # ============================================================================
    echo -e "${BLUE}Nemotron Model (Table Structure):${NC}"
    
    NEMOTRON_PATH="${FARIA_NEMOTRON_MODEL_PATH:-}"
    if [ -z "${NEMOTRON_PATH}" ] || [ ! -f "${NEMOTRON_PATH}" ]; then
        NEMOTRON_PATH="${INSTALL_DIR}/models/nemotron_table_structure.onnx"
    fi
    
    if [ -f "${NEMOTRON_PATH}" ]; then
        MODEL_SIZE=$(du -h "${NEMOTRON_PATH}" | cut -f1)
        echo -e "  ${CHECK} Found (${MODEL_SIZE})"
        echo "     ${NEMOTRON_PATH}"
    else
        echo -e "  ${CROSS} Not found"
        echo "     Expected: ${INSTALL_DIR}/models/nemotron_table_structure.onnx"
        ALL_REQUIRED_OK=false
        MISSING_COMPONENTS="${MISSING_COMPONENTS}Nemotron Model, "
    fi
    echo ""
    
    # ============================================================================
    # Check IDP Dependencies (OpenCV, Tesseract, Leptonica, MuPDF)
    # ============================================================================
    echo -e "${BLUE}IDP Dependencies:${NC}"
    
    # Check Leptonica
    if pkg-config --exists lept 2>/dev/null; then
        LEPT_VERSION=$(pkg-config --modversion lept 2>/dev/null || echo "0.0.0")
        check_version "leptonica" "$LEPT_VERSION"
    else
        echo -e "  ${WARN} leptonica: Not found (needed for IDP)"
    fi
    
    # Check Tesseract
    if command -v tesseract &> /dev/null; then
        TESSERACT_VERSION=$(tesseract --version 2>&1 | head -n1 | sed 's/tesseract //' | cut -d' ' -f1)
        TESSERACT_PATH=$(which tesseract)
        if check_version "tesseract" "$TESSERACT_VERSION"; then
            echo "     Path: ${TESSERACT_PATH}"
        fi
    else
        echo -e "  ${WARN} tesseract: Not found (needed for IDP)"
        echo "     Install: brew install tesseract (macOS) or apt install tesseract-ocr (Linux)"
    fi
    
    # Check OpenCV — ensure the user-space install dir is on PKG_CONFIG_PATH
    export PKG_CONFIG_PATH="${INSTALL_DIR}/lib/opencv/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
    if pkg-config --exists opencv4 2>/dev/null; then
        OPENCV_VERSION=$(pkg-config --modversion opencv4 2>/dev/null || echo "0.0.0")
        check_version "opencv" "$OPENCV_VERSION"
    else
        echo -e "  ${WARN} opencv: Not found (needed for IDP)"
        echo "     Install: brew install opencv (macOS) or run ./scripts/install-opencv.sh (Linux)"
        echo "     Hint: set PKG_CONFIG_PATH=\"${INSTALL_DIR}/lib/opencv/lib/pkgconfig:\$PKG_CONFIG_PATH\""
    fi
    
    # Check MuPDF
    if command -v mutool &> /dev/null; then
        MUPDF_VERSION=$(mutool -v 2>&1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1 || echo "installed")
        echo -e "  ${CHECK} mupdf: ${MUPDF_VERSION}"
    elif pkg-config --exists mupdf 2>/dev/null; then
        MUPDF_VERSION=$(pkg-config --modversion mupdf 2>/dev/null || echo "installed")
        echo -e "  ${CHECK} mupdf: ${MUPDF_VERSION}"
    else
        echo -e "  ${WARN} mupdf: Not found (needed for IDP)"
        echo "     Install: brew install mupdf (macOS) or apt install mupdf mupdf-tools (Linux)"
    fi
    
    echo ""
    
    # ============================================================================
    # Check LLM Components (Optional)
    # ============================================================================
    echo -e "${BLUE}LLM Components (Optional):${NC}"
    
    # Check llama-cli
    LLAMA_PATH="${FARIA_LLAMA_CLI_PATH:-}"
    if [ -z "${LLAMA_PATH}" ] || [ ! -f "${LLAMA_PATH}" ]; then
        LLAMA_PATH="${INSTALL_DIR}/bin/llama-cli"
    fi
    
    if [ -x "${LLAMA_PATH}" ]; then
        echo -e "  ${CHECK} llama-cli: Found"
        echo "     ${LLAMA_PATH}"
    else
        echo -e "  ${WARN} llama-cli: Not found (optional)"
    fi
    
    # Check Qwen model
    QWEN_PATH="${FARIA_SLM_MODEL_PATH:-}"
    if [ -z "${QWEN_PATH}" ] || [ ! -f "${QWEN_PATH}" ]; then
        QWEN_PATH="${INSTALL_DIR}/models/qwen2.5-0.5b-instruct-q8_0.gguf"
    fi
    
    if [ -f "${QWEN_PATH}" ]; then
        MODEL_SIZE=$(du -h "${QWEN_PATH}" | cut -f1)
        echo -e "  ${CHECK} Qwen model: Found (${MODEL_SIZE})"
        echo "     ${QWEN_PATH}"
    else
        echo -e "  ${WARN} Qwen model: Not found (optional)"
    fi
    echo ""
    
    # ============================================================================
    # Summary
    # ============================================================================
    echo -e "${BLUE}========================================${NC}"
    
    if [ "${ALL_REQUIRED_OK}" = true ]; then
        echo -e "${GREEN}  All required components installed!${NC}"
        echo -e "${BLUE}========================================${NC}"
        echo ""
        echo -e "${YELLOW}Environment variables (optional):${NC}"
        echo ""
        echo "  export FARIA_ONNXRUNTIME_PATH=\"${ONNX_PATH}\""
        echo "  export FARIA_DETR_MODEL_PATH=\"${DETR_PATH}\""
        echo "  export FARIA_NEMOTRON_MODEL_PATH=\"${NEMOTRON_PATH}\""
        if [ -x "${LLAMA_PATH}" ]; then
            echo "  export FARIA_LLAMA_CLI_PATH=\"${LLAMA_PATH}\""
        fi
        if [ -f "${QWEN_PATH}" ]; then
            echo "  export FARIA_SLM_MODEL_PATH=\"${QWEN_PATH}\""
        fi
        echo ""
        echo -e "${GREEN}Faria is ready to use!${NC}"
    else
        echo -e "${RED}  Missing required components!${NC}"
        echo -e "${BLUE}========================================${NC}"
        echo ""
        # Remove trailing comma and space
        MISSING_COMPONENTS="${MISSING_COMPONENTS%, }"
        echo -e "${RED}Missing: ${MISSING_COMPONENTS}${NC}"
        echo ""
        echo "Run the installation scripts to install missing components:"
        echo "  ./scripts/install.sh"
        echo ""
        return 1
    fi
    echo ""
}

# ============================================================================
# __install_idp() - from install-idp.sh
# ============================================================================
__install_idp() {
    #
    # Faria IDP (Intelligent Document Processing) Installation Script
    # Orchestrates installation of all IDP dependencies:
    #   - OpenCV (image processing)
    #   - Tesseract + Leptonica (OCR)
    #   - MuPDF (PDF processing)
    #   - ONNX Runtime (model inference)
    #   - DETR + Nemotron models (layout detection, table extraction)
    #
    # Usage: ./install-idp.sh [OPTIONS]
    #
    
    
    # Colors for output
    
    # Default options
    INSTALL_DIR="${HOME}/.faria"
    ENABLE_GPU=false
    INSTALL_LLM=false
    SYSTEM_FLAG=""
    
    # Get script directory
    
    # ---------------------------------------------------------------------------
    # Curl-aware bootstrap — same pattern as install.sh.
    # install-idp.sh's leaf scripts are siblings (no scripts/ subdir), so
    # the bootstrap downloads them flat into the temp directory.
    # ---------------------------------------------------------------------------
    _REMOTE_BASE="${FARIA_INSTALL_RAW:-https://raw.githubusercontent.com/exto360-inc/faria-install/main}/scripts"
    _BOOTSTRAP_TMPDIR=""
    
    _bootstrap_scripts() {
        if [ ! -f __install_opencv ]; then
            echo "Bootstrapping: downloading leaf scripts from ${_REMOTE_BASE} ..."
            _BOOTSTRAP_TMPDIR=$(mktemp -d)
    
            # Detect download tool
            if command -v curl &> /dev/null; then
                _dl() { curl -fsSL "$1" -o "$2"; }
            elif command -v wget &> /dev/null; then
                _dl() { wget -qO "$2" "$1"; }
            else
                echo "Error: neither curl nor wget found. Please install one and retry."
                return 1
            fi
    
            # setup-python.sh needed by install-models.sh local mode;
            # install-slm.sh needed when --with-llm is used
            for s in install-opencv.sh install-tesseract.sh install-mupdf.sh \
                      install-onnxruntime.sh install-models.sh install-slm.sh setup-python.sh; do
                if ! _dl "${_REMOTE_BASE}/${s}" "${_BOOTSTRAP_TMPDIR}/${s}"; then
                    echo "Error: failed to download ${s} from ${_REMOTE_BASE}"
                    return 1
                fi
                chmod +x "${_BOOTSTRAP_TMPDIR}/${s}" 2>/dev/null || true
            done
        fi
    }
    
    _cleanup_bootstrap() {
        [ -n "${_BOOTSTRAP_TMPDIR}" ] && rm -rf "${_BOOTSTRAP_TMPDIR}"
    }
    trap '_cleanup_bootstrap' EXIT
    
    _bootstrap_scripts
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --install-dir)
                INSTALL_DIR="$2"
                shift 2
                ;;
            --gpu)
                ENABLE_GPU=true
                shift
                ;;
            --system)
                SYSTEM_FLAG="--system"
                shift
                ;;
            --with-llm)
                INSTALL_LLM=true
                shift
                ;;
            --help|-h)
                echo "Faria IDP Installation Script"
                echo ""
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --install-dir DIR  Install to DIR (default: ~/.faria)"
                echo "  --gpu              Enable GPU support (CUDA on Linux)"
                echo "  --system           Install ONNX Runtime system-wide (/usr/local) with headers (for Docker/CGO builds)"
                echo "  --with-llm         Install LLM support for advanced document understanding"
                echo "  --help, -h         Show this help message"
                echo ""
                echo "This script installs all dependencies for IDP (Intelligent Document Processing):"
                echo "  - OpenCV           Image processing"
                echo "  - Tesseract        OCR engine"
                echo "  - Leptonica        Image library (with Tesseract)"
                echo "  - MuPDF            PDF processing"
                echo "  - ONNX Runtime     Model inference"
                echo "  - DETR model       Layout detection"
                echo "  - Nemotron model   Table extraction"
                return 0
                ;;
            *)
                echo "Unknown option: $1"
                echo "Use --help for usage information"
                return 1
                ;;
        esac
    done
    
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}   ${BLUE}Faria IDP Dependencies Installation${NC}                        ${CYAN}║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "${YELLOW}Install directory:${NC} ${INSTALL_DIR}"
    echo ""
    
    # Track installation status
    INSTALL_FAILED=false
    TOTAL_STEPS=5
    if [ "${INSTALL_LLM}" = true ]; then
        TOTAL_STEPS=$((TOTAL_STEPS + 1))
    fi
    CURRENT_STEP=0
    
    # Helper function to run a step
    function _local_run_step {
        local step_name=$1
        local script=$2
        shift 2
        local args=("$@")
    
        CURRENT_STEP=$((CURRENT_STEP + 1))
        echo ""
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${BLUE}  Step ${CURRENT_STEP}/${TOTAL_STEPS}: ${step_name}${NC}"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
    
        if "${SCRIPT_DIR}/${script}" "${args[@]}"; then
            echo -e "${GREEN}✓ ${step_name} completed successfully${NC}"
        else
            echo -e "${RED}✗ ${step_name} failed${NC}"
            INSTALL_FAILED=true
        fi
    }
    
    # Create install directory
    mkdir -p "${INSTALL_DIR}"
    
    # Step 1: Install OpenCV
    run_step "Installing OpenCV" "install-opencv.sh" --install-dir "${INSTALL_DIR}"
    # Make opencv4.pc discoverable for subsequent CGO builds in this session
    export PKG_CONFIG_PATH="${INSTALL_DIR}/lib/opencv/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
    
    # Step 2: Install Tesseract (includes Leptonica)
    run_step "Installing Tesseract OCR" "install-tesseract.sh"
    
    # Step 3: Install MuPDF
    run_step "Installing MuPDF" "install-mupdf.sh"
    
    # Step 4: Install ONNX Runtime
    GPU_FLAG=""
    if [ "${ENABLE_GPU}" = true ]; then
        GPU_FLAG="--gpu"
    fi
    run_step "Installing ONNX Runtime" "install-onnxruntime.sh" --install-dir "${INSTALL_DIR}" ${GPU_FLAG} ${SYSTEM_FLAG}
    
    # Step 5: Install ML Models (DETR + Nemotron)
    run_step "Installing ML Models" "install-models.sh" --install-dir "${INSTALL_DIR}" ${SYSTEM_FLAG}
    
    # Step 6 (optional): Install LLM for IDP
    if [ "${INSTALL_LLM}" = true ]; then
        run_step "Installing LLM for IDP" "install-slm.sh" --install-dir "${INSTALL_DIR}"
    fi
    
    # Final Summary
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    if [ "${INSTALL_FAILED}" = false ]; then
        echo -e "${CYAN}║${NC}   ${GREEN}IDP Dependencies Installed Successfully!${NC}                   ${CYAN}║${NC}"
    else
        echo -e "${CYAN}║${NC}   ${YELLOW}IDP Installation Completed with Warnings${NC}                   ${CYAN}║${NC}"
    fi
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "${YELLOW}Installed components:${NC}"
    echo "  • OpenCV       - Image processing"
    echo "  • Tesseract    - OCR engine"
    echo "  • Leptonica    - Image library"
    echo "  • MuPDF        - PDF processing"
    echo "  • ONNX Runtime - Model inference"
    echo "  • DETR model   - Layout detection"
    echo "  • Nemotron     - Table extraction"
    if [ "${INSTALL_LLM}" = true ]; then
        echo "  • LLM          - Advanced document understanding"
    fi
    echo ""
    
    if [ "${INSTALL_FAILED}" = true ]; then
        return 1
    fi
}

# ============================================================================
# __install_chat() - from install-chat.sh
# ============================================================================
__install_chat() {
    #
    # Faria Chat Installation Script
    # Orchestrates installation of Chat feature dependencies:
    #   - llama.cpp (LLM inference engine)
    #   - Qwen 2.5 model (language model)
    #
    # Usage: ./install-chat.sh [OPTIONS]
    #
    
    
    # Colors for output
    
    # Default options
    INSTALL_DIR="${HOME}/.faria"
    
    # Get script directory
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --install-dir)
                INSTALL_DIR="$2"
                shift 2
                ;;
            --help|-h)
                echo "Faria Chat Installation Script"
                echo ""
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --install-dir DIR  Install to DIR (default: ~/.faria)"
                echo "  --help, -h         Show this help message"
                echo ""
                echo "This script installs dependencies for the Chat feature:"
                echo "  - llama.cpp        LLM inference engine (~5 MB)"
                echo "  - Qwen 2.5-0.5B    Language model (~530 MB)"
                return 0
                ;;
            *)
                echo "Unknown option: $1"
                echo "Use --help for usage information"
                return 1
                ;;
        esac
    done
    
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}   ${BLUE}Faria Chat Dependencies Installation${NC}                       ${CYAN}║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "${YELLOW}Install directory:${NC} ${INSTALL_DIR}"
    echo ""
    
    # Create install directory
    mkdir -p "${INSTALL_DIR}"
    
    # Track installation status
    INSTALL_FAILED=false
    
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  Installing LLM Components (llama.cpp + Qwen)${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    if __install_slm --install-dir "${INSTALL_DIR}"; then
        echo -e "${GREEN}✓ LLM Components installed successfully${NC}"
    else
        echo -e "${RED}✗ LLM Components installation failed${NC}"
        INSTALL_FAILED=true
    fi
    
    # Final Summary
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    if [ "${INSTALL_FAILED}" = false ]; then
        echo -e "${CYAN}║${NC}   ${GREEN}Chat Dependencies Installed Successfully!${NC}                  ${CYAN}║${NC}"
    else
        echo -e "${CYAN}║${NC}   ${YELLOW}Chat Installation Completed with Warnings${NC}                  ${CYAN}║${NC}"
    fi
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "${YELLOW}Installed components:${NC}"
    echo "  • llama.cpp    - LLM inference engine"
    echo "  • Qwen 2.5     - Language model for chat and cross-page table merging"
    echo ""
    
    if [ "${INSTALL_FAILED}" = true ]; then
        return 1
    fi
}

# ============================================================================
# Main Orchestrator
# ============================================================================

#
# Faria Installation Script
# Main orchestration script for installing Faria dependencies
#
# Usage: ./install.sh [OPTIONS]
#
# Features:
#   idp  - Intelligent Document Processing (OpenCV, Tesseract, MuPDF, ONNX, models)
#   chat - Conversational AI (llama.cpp, Qwen model)
#
# Examples:
#   ./install.sh --features idp          # Install IDP only
#   ./install.sh --features chat         # Install Chat only
#   ./install.sh --features idp,chat     # Install both
#   ./install.sh --features all          # Install everything
#   ./install.sh                         # Interactive mode
#


# Colors for output

# Default options
INSTALL_DIR="${HOME}/.faria"
ENABLE_GPU=false
FEATURES=""  # Empty means prompt, comma-separated list of features
SYSTEM_FLAG=""

# Get script directory

# ---------------------------------------------------------------------------
# Curl-aware bootstrap
# When run via `curl | bash`, BASH_SOURCE[0] is not the repo path so
# sub-scripts are not found at ${SCRIPT_DIR}/scripts/. Detect this and
# download them to a temp directory instead.
#
# FARIA_INSTALL_RAW must point to the repo root (no /scripts suffix).
# The bootstrap appends /scripts internally.
# ---------------------------------------------------------------------------
_REMOTE_BASE="${FARIA_INSTALL_RAW:-https://raw.githubusercontent.com/exto360-inc/faria-install/main}/scripts"
_BOOTSTRAP_TMPDIR=""

_bootstrap_scripts() {
    if [ ! -f __install_idp ]; then
        echo "Bootstrapping: downloading sub-scripts from ${_REMOTE_BASE} ..."
        _BOOTSTRAP_TMPDIR=$(mktemp -d)
        mkdir -p "${_BOOTSTRAP_TMPDIR}/scripts"

        # Detect download tool
        if command -v curl &> /dev/null; then
            _dl() { curl -fsSL "$1" -o "$2"; }
        elif command -v wget &> /dev/null; then
            _dl() { wget -qO "$2" "$1"; }
        else
            echo "Error: neither curl nor wget found. Please install one and retry."
            exit 1
        fi

        # Download sub-scripts (setup-python.sh needed by install-models.sh local mode;
        # install-slm.sh needed when --with-llm is used)
        for s in install-idp.sh install-opencv.sh install-tesseract.sh \
                  install-mupdf.sh install-onnxruntime.sh install-models.sh \
                  install-chat.sh install-slm.sh verify.sh setup-python.sh; do
            if ! _dl "${_REMOTE_BASE}/${s}" "${_BOOTSTRAP_TMPDIR}/scripts/${s}"; then
                echo "Error: failed to download ${s} from ${_REMOTE_BASE}"
                exit 1
            fi
            chmod +x "${_BOOTSTRAP_TMPDIR}/scripts/${s}" 2>/dev/null || true
        done

        # Download versions.json (needed by verify.sh which looks at ../versions.json)
        _REMOTE_ROOT="${FARIA_INSTALL_RAW:-https://raw.githubusercontent.com/exto360-inc/faria-install/main}"
        if ! _dl "${_REMOTE_ROOT}/versions.json" "${_BOOTSTRAP_TMPDIR}/versions.json"; then
            echo "Error: failed to download versions.json from ${_REMOTE_ROOT}"
            exit 1
        fi

    fi
}

# Note: trap replaces any previously-registered EXIT handler. This is intentional —
# bootstrap cleanup is the only EXIT action needed at this scope.
_cleanup_bootstrap() {
    [ -n "${_BOOTSTRAP_TMPDIR}" ] && rm -rf "${_BOOTSTRAP_TMPDIR}"
}
trap '_cleanup_bootstrap' EXIT

_bootstrap_scripts

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --install-dir)
            INSTALL_DIR="$2"
            shift 2
            ;;
        --gpu)
            ENABLE_GPU=true
            shift
            ;;
        --system)
            SYSTEM_FLAG="--system"
            shift
            ;;
        --features)
            FEATURES="$2"
            shift 2
            ;;
        --help|-h)
            echo "Faria Installation Script"
            echo ""
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --features LIST    Comma-separated list of features to install"
            echo "                     Available: idp, chat, all"
            echo "  --install-dir DIR  Install to DIR (default: ~/.faria)"
            echo "  --gpu              Enable GPU support (CUDA on Linux)"
            echo "  --system           Install ONNX Runtime system-wide (/usr/local) with headers (for Docker/CGO builds)"
            echo "  --help, -h         Show this help message"
            echo ""
            echo "Features:"
            echo "  idp   - Intelligent Document Processing (~630 MB)"
            echo "          OpenCV, Tesseract, Leptonica, MuPDF, ONNX Runtime,"
            echo "          DETR model, Nemotron model"
            echo "          Optional: LLM support (~500 MB extra, prompted during install)"
            echo ""
            echo "  chat  - Conversational AI (~535 MB)"
            echo "          llama.cpp, Qwen 2.5 model"
            echo ""
            echo "Examples:"
            echo "  $0 --features idp           # IDP (prompts for LLM option)"
            echo "  $0 --features chat          # Chat only"
            echo "  $0 --features idp,chat      # Both features"
            echo "  $0 --features all           # Everything"
            echo "  $0                          # Interactive mode"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Banner
echo ""
echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${NC}                                                               ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}   ${BLUE}███████╗ █████╗ ██████╗ ██╗ █████╗${NC}                          ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}   ${BLUE}██╔════╝██╔══██╗██╔══██╗██║██╔══██╗${NC}                         ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}   ${BLUE}█████╗  ███████║██████╔╝██║███████║${NC}                         ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}   ${BLUE}██╔══╝  ██╔══██║██╔══██╗██║██╔══██║${NC}                         ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}   ${BLUE}██║     ██║  ██║██║  ██║██║██║  ██║${NC}                         ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}   ${BLUE}╚═╝     ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝╚═╝  ╚═╝${NC}                         ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}                                                               ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}   ${GREEN}AI Toolkit                     ${NC}                             ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}                                                               ${CYAN}║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Detect OS
OS="$(uname -s)"
ARCH="$(uname -m)"

echo -e "${YELLOW}System detected:${NC} ${OS} (${ARCH})"
echo -e "${YELLOW}Install directory:${NC} ${INSTALL_DIR}"
echo ""

# Show available features
echo -e "${BLUE}Available features:${NC}"
echo ""
echo -e "  ${GREEN}idp${NC}  - Intelligent Document Processing (~630 MB)"
echo "         OpenCV, Tesseract, Leptonica, MuPDF, ONNX Runtime,"
echo "         DETR model (layout detection), Nemotron model (tables)"
echo ""
echo -e "  ${GREEN}chat${NC} - Conversational AI (~535 MB)"
echo "         llama.cpp, Qwen 2.5 model"
echo ""

# Prompt for features if not specified
if [ -z "${FEATURES}" ]; then
    if [ ! -t 0 ]; then
        echo "Error: --features is required in non-interactive mode."
        echo "  Example: curl -fsSL ... | bash -s -- --features idp"
        exit 1
    fi
    echo -e "${YELLOW}Which features do you want to install?${NC}"
    echo ""
    echo "  1) idp only      - Document processing"
    echo "  2) chat only     - Conversational AI"
    echo "  3) idp + chat    - Both features"
    echo "  4) Cancel"
    echo ""
    read -p "Enter choice [1-4]: " -n 1 -r
    echo
    case $REPLY in
        1) FEATURES="idp" ;;
        2) FEATURES="chat" ;;
        3) FEATURES="idp,chat" ;;
        4|*)
            echo "Installation cancelled."
            exit 0
            ;;
    esac
fi

# Normalize "all" to actual features
if [ "${FEATURES}" = "all" ]; then
    FEATURES="idp,chat"
fi

# Parse features into flags
INSTALL_IDP=false
INSTALL_CHAT=false

IFS=',' read -ra FEATURE_ARRAY <<< "${FEATURES}"
for feature in "${FEATURE_ARRAY[@]}"; do
    feature=$(echo "$feature" | tr -d ' ')
    case "$feature" in
        idp) INSTALL_IDP=true ;;
        chat) INSTALL_CHAT=true ;;
        *) echo -e "${YELLOW}Warning: Unknown feature '${feature}' ignored${NC}" ;;
    esac
done

# Validate at least one feature selected
if [ "${INSTALL_IDP}" = false ] && [ "${INSTALL_CHAT}" = false ]; then
    echo -e "${RED}Error: No valid features selected${NC}"
    exit 1
fi

# Ask about LLM for IDP if IDP is selected
INSTALL_IDP_LLM=false
if [ "${INSTALL_IDP}" = true ]; then
    echo ""
    echo -e "${YELLOW}Would you like to install LLM support for IDP?${NC}"
    echo "  This enables advanced document understanding capabilities."
    echo "  (Requires additional ~500 MB disk space)"
    echo ""
    if [ -t 0 ]; then
        read -p "Install LLM for IDP? (y/N): " -n 1 -r
        echo
    else
        REPLY="N"
    fi
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        INSTALL_IDP_LLM=true
    fi
fi

echo ""
echo -e "${BLUE}Installation summary:${NC}"
echo "  • IDP (Document Processing): $([ "${INSTALL_IDP}" = true ] && echo "yes" || echo "no")"
if [ "${INSTALL_IDP}" = true ]; then
    echo "    └─ LLM support: $([ "${INSTALL_IDP_LLM}" = true ] && echo "yes" || echo "no")"
fi
echo "  • Chat (Conversational AI): $([ "${INSTALL_CHAT}" = true ] && echo "yes" || echo "no")"
if [ "${OS}" = "Darwin" ]; then
    echo "  • Core ML: yes (if IDP selected)"
else
    echo "  • GPU support: $([ "${ENABLE_GPU}" = true ] && echo "yes" || echo "no")"
fi
echo ""

if [ -t 0 ]; then
    read -p "Continue with installation? (Y/n): " -n 1 -r
    echo
else
    REPLY="Y"
fi
if [[ $REPLY =~ ^[Nn]$ ]]; then
    echo "Installation cancelled."
    exit 0
fi

echo ""

# Create install directory
mkdir -p "${INSTALL_DIR}"

# Track installation status
INSTALL_FAILED=false
CURRENT_STEP=0
TOTAL_STEPS=0

# Calculate total steps
if [ "${INSTALL_IDP}" = true ]; then
    TOTAL_STEPS=$((TOTAL_STEPS + 1))  # IDP orchestrator
fi
if [ "${INSTALL_CHAT}" = true ]; then
    TOTAL_STEPS=$((TOTAL_STEPS + 1))  # Chat orchestrator
fi
TOTAL_STEPS=$((TOTAL_STEPS + 1))  # Verification

# ============================================================================
# Install IDP Feature
# ============================================================================
if [ "${INSTALL_IDP}" = true ]; then
    CURRENT_STEP=$((CURRENT_STEP + 1))
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  Step ${CURRENT_STEP}/${TOTAL_STEPS}: Installing IDP Feature${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    GPU_FLAG=""
    if [ "${ENABLE_GPU}" = true ]; then
        GPU_FLAG="--gpu"
    fi

    LLM_FLAG=""
    if [ "${INSTALL_IDP_LLM}" = true ]; then
        LLM_FLAG="--with-llm"
    fi

    if __install_idp --install-dir "${INSTALL_DIR}" ${GPU_FLAG} ${LLM_FLAG} ${SYSTEM_FLAG}; then
        echo -e "${GREEN}✓ IDP Feature installed successfully${NC}"
    else
        echo -e "${RED}✗ IDP Feature installation failed${NC}"
        INSTALL_FAILED=true
    fi

    echo ""
fi

# ============================================================================
# Install Chat Feature
# ============================================================================
if [ "${INSTALL_CHAT}" = true ]; then
    CURRENT_STEP=$((CURRENT_STEP + 1))
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  Step ${CURRENT_STEP}/${TOTAL_STEPS}: Installing Chat Feature${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    if __install_chat --install-dir "${INSTALL_DIR}"; then
        echo -e "${GREEN}✓ Chat Feature installed successfully${NC}"
    else
        echo -e "${RED}✗ Chat Feature installation failed${NC}"
        INSTALL_FAILED=true
    fi

    echo ""
fi

# ============================================================================
# Verify Installation
# ============================================================================
CURRENT_STEP=$((CURRENT_STEP + 1))
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Step ${CURRENT_STEP}/${TOTAL_STEPS}: Verifying Installation${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

__verify_installation --install-dir "${INSTALL_DIR}" ${SYSTEM_FLAG}

# ============================================================================
# Final Summary
# ============================================================================
echo ""
echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
if [ "${INSTALL_FAILED}" = false ]; then
    echo -e "${CYAN}║${NC}                                                               ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}   ${GREEN}Installation Complete!${NC}                                      ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}                                                               ${CYAN}║${NC}"
else
    echo -e "${CYAN}║${NC}                                                               ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}   ${YELLOW}Installation completed with warnings${NC}                        ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}                                                               ${CYAN}║${NC}"
fi
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${YELLOW}Installed features:${NC}"
if [ "${INSTALL_IDP}" = true ]; then
    echo "  • IDP - OpenCV, Tesseract, MuPDF, ONNX Runtime, DETR, Nemotron"
fi
if [ "${INSTALL_CHAT}" = true ]; then
    echo "  • Chat - llama.cpp, Qwen 2.5"
fi
echo ""

echo -e "${YELLOW}Next steps:${NC}"
echo ""
echo "1. Add environment variables to your shell profile (optional):"
echo "   See the output above for the exact paths."
echo ""
echo "2. Or use auto-detection (no configuration needed):"
echo "   Faria will automatically find files in ~/.faria/"
echo ""
echo "3. Start using Faria in your Go code:"
echo ""
echo -e "   ${BLUE}config := faria.DefaultConfig()${NC}"
echo -e "   ${BLUE}client, err := faria.New(config)${NC}"
echo ""
echo "For more information, see: https://github.com/exto360-inc/faria"
echo ""

# Cleanup models cache on exit
trap __cleanup_models_cache EXIT
