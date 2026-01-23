#!/bin/bash
#
# Faria SLM Installation Script
# Downloads and installs llama-cli and Qwen model for SLM features
#
# Usage: ./install-slm.sh [--install-dir DIR]
#
# Default install location: ~/.faria/
#

set -e

# Configuration
LLAMA_CPP_VERSION="b4549"
QWEN_MODEL="qwen2.5-0.5b-instruct-q8_0.gguf"
QWEN_MODEL_URL="https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/${QWEN_MODEL}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
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
                exit 1
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
                exit 1
                ;;
        esac
        ;;
    *)
        echo -e "${RED}Unsupported OS: ${OS}${NC}"
        echo "For Windows, please use install-slm.ps1"
        exit 1
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
    exit 1
fi

echo -e "${YELLOW}Extracting llama.cpp...${NC}"
unzip -q "${TEMP_DIR}/llama.zip" -d "${TEMP_DIR}/llama"

# Find and copy llama-cli
LLAMA_CLI=$(find "${TEMP_DIR}/llama" -name "llama-cli" -type f | head -1)
if [ -z "${LLAMA_CLI}" ]; then
    echo -e "${RED}Error: llama-cli not found in archive${NC}"
    exit 1
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
    exit 1
fi

if [ -f "${MODEL_PATH}" ]; then
    MODEL_SIZE=$(du -h "${MODEL_PATH}" | cut -f1)
    echo -e "${GREEN}  Model: OK (${MODEL_SIZE})${NC}"
else
    echo -e "${RED}  Model: FAILED${NC}"
    exit 1
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
