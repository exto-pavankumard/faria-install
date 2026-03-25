#!/bin/bash
#
# Faria ONNX Runtime Installation Script
# Downloads and installs ONNX Runtime with CoreML support (macOS) or CUDA support (Linux)
#
# Usage: ./install-onnxruntime.sh [OPTIONS]
#
# IMPORTANT: Do NOT use Homebrew on macOS - the Homebrew version lacks CoreML/Neural Engine support.
# This script downloads the official release which includes CoreML execution provider.
#

set -e

# Configuration
ONNXRUNTIME_VERSION="1.22.0"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
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
    exit 1
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
    exit 1
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
                exit 1
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
                exit 1
                ;;
        esac
        ;;
    *)
        echo -e "${RED}Unsupported OS: ${OS}${NC}"
        echo "For Windows, please use install-onnxruntime.ps1"
        exit 1
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
        exit 0
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
    exit 1
fi

echo -e "${YELLOW}Extracting ONNX Runtime...${NC}"
tar -xzf "${TEMP_DIR}/onnxruntime.tgz" -C "${TEMP_DIR}"

# Find and copy library files
EXTRACTED_DIR=$(find "${TEMP_DIR}" -maxdepth 1 -type d -name "onnxruntime-*" | head -1)
if [ -z "${EXTRACTED_DIR}" ]; then
    echo -e "${RED}Error: Could not find extracted ONNX Runtime directory${NC}"
    exit 1
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
    exit 1
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
