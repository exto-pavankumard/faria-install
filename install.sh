#!/bin/bash
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

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default options
INSTALL_DIR="${HOME}/.faria"
ENABLE_GPU=false
FEATURES=""  # Empty means prompt, comma-separated list of features

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

    if "${SCRIPT_DIR}/scripts/install-idp.sh" --install-dir "${INSTALL_DIR}" ${GPU_FLAG} ${LLM_FLAG}; then
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

    if "${SCRIPT_DIR}/scripts/install-chat.sh" --install-dir "${INSTALL_DIR}"; then
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

"${SCRIPT_DIR}/scripts/verify.sh" --install-dir "${INSTALL_DIR}"

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
