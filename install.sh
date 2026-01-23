#!/bin/bash
#
# Faria Installation Script
# Main orchestration script for installing all Faria dependencies
#
# Usage: ./install.sh [OPTIONS]
#
# This script installs:
#   Required:
#     - ONNX Runtime (inference engine)
#     - DETR model (layout detection)
#     - Nemotron model (table structure)
#     - Tesseract OCR (text extraction)
#   Optional:
#     - llama.cpp + Qwen model (cross-page table merging)
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
WITH_LLM=""  # Empty means prompt, "true" or "false" means skip prompt
SKIP_TESSERACT=false

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
        --with-llm)
            WITH_LLM="true"
            shift
            ;;
        --no-llm)
            WITH_LLM="false"
            shift
            ;;
        --skip-tesseract)
            SKIP_TESSERACT=true
            shift
            ;;
        --help|-h)
            echo "Faria Installation Script"
            echo ""
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --install-dir DIR  Install to DIR (default: ~/.faria)"
            echo "  --gpu              Enable GPU support (CUDA on Linux)"
            echo "  --with-llm         Install LLM components without prompting"
            echo "  --no-llm           Skip LLM components without prompting"
            echo "  --skip-tesseract   Skip Tesseract if already installed"
            echo "  --help, -h         Show this help message"
            echo ""
            echo "Components:"
            echo "  Required:"
            echo "    - ONNX Runtime    Model inference engine (~50 MB)"
            echo "    - DETR            Layout detection model (~350 MB)"
            echo "    - Nemotron        Table structure model (~200 MB)"
            echo "    - Tesseract OCR   Text extraction (~30 MB)"
            echo ""
            echo "  Optional (LLM for cross-page table merging):"
            echo "    - llama.cpp       LLM inference engine (~5 MB)"
            echo "    - Qwen 2.5        Language model (~530 MB)"
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
echo -e "${CYAN}║${NC}   ${GREEN}Intelligent Document Processing${NC}                             ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}                                                               ${CYAN}║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Detect OS
OS="$(uname -s)"
ARCH="$(uname -m)"

echo -e "${YELLOW}System detected:${NC} ${OS} (${ARCH})"
echo -e "${YELLOW}Install directory:${NC} ${INSTALL_DIR}"
echo ""

# Show what will be installed
echo -e "${BLUE}This script will install:${NC}"
echo ""
echo -e "  ${GREEN}Required components:${NC}"
echo "    • ONNX Runtime    - Model inference engine"
echo "    • DETR model      - Document layout detection"
echo "    • Nemotron model  - Table structure detection"
if [ "${SKIP_TESSERACT}" = false ]; then
    echo "    • Tesseract OCR   - Text extraction"
else
    echo -e "    • Tesseract OCR   - ${YELLOW}(skipped)${NC}"
fi
echo ""
echo -e "  ${YELLOW}Optional components:${NC}"
echo "    • LLM (llama.cpp + Qwen) - Cross-page table merging"
echo ""

# Prompt for LLM if not specified
if [ -z "${WITH_LLM}" ]; then
    echo -e "${YELLOW}The LLM component enables intelligent cross-page table merging.${NC}"
    echo "It requires ~535 MB of additional disk space."
    echo ""
    read -p "Do you want to install LLM components? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        WITH_LLM="true"
    else
        WITH_LLM="false"
    fi
fi

echo ""
echo -e "${BLUE}Installation summary:${NC}"
echo "  • ONNX Runtime: yes"
echo "  • DETR model: yes"
echo "  • Nemotron model: yes"
echo "  • Tesseract OCR: $([ "${SKIP_TESSERACT}" = true ] && echo "skip" || echo "yes")"
echo "  • LLM components: $([ "${WITH_LLM}" = "true" ] && echo "yes" || echo "no")"
if [ "${OS}" = "Darwin" ]; then
    echo "  • Core ML: yes"
else
    echo "  • GPU support: $([ "${ENABLE_GPU}" = true ] && echo "yes" || echo "no")"
fi
echo ""

read -p "Continue with installation? (Y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Nn]$ ]]; then
    echo "Installation cancelled."
    exit 0
fi

echo ""

# Create install directory
mkdir -p "${INSTALL_DIR}"

# Track installation status
INSTALL_FAILED=false

# ============================================================================
# Step 1: Install ONNX Runtime
# ============================================================================
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Step 1/$([ "${WITH_LLM}" = "true" ] && echo "5" || echo "4"): Installing ONNX Runtime${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

GPU_FLAG=""
if [ "${ENABLE_GPU}" = true ]; then
    GPU_FLAG="--gpu"
fi

if "${SCRIPT_DIR}/scripts/install-onnxruntime.sh" --install-dir "${INSTALL_DIR}" ${GPU_FLAG}; then
    echo -e "${GREEN}✓ ONNX Runtime installed successfully${NC}"
else
    echo -e "${RED}✗ ONNX Runtime installation failed${NC}"
    INSTALL_FAILED=true
fi

echo ""

# ============================================================================
# Step 2: Install Tesseract OCR
# ============================================================================
if [ "${SKIP_TESSERACT}" = false ]; then
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  Step 2/$([ "${WITH_LLM}" = "true" ] && echo "5" || echo "4"): Installing Tesseract OCR${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    if "${SCRIPT_DIR}/scripts/install-tesseract.sh"; then
        echo -e "${GREEN}✓ Tesseract OCR installed successfully${NC}"
    else
        echo -e "${RED}✗ Tesseract OCR installation failed${NC}"
        INSTALL_FAILED=true
    fi

    echo ""
fi

# ============================================================================
# Step 3: Install ML Models (DETR + Nemotron)
# ============================================================================
STEP_NUM=$((SKIP_TESSERACT ? 2 : 3))
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Step ${STEP_NUM}/$([ "${WITH_LLM}" = "true" ] && echo "5" || echo "4"): Installing ML Models (DETR + Nemotron)${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if "${SCRIPT_DIR}/scripts/install-models.sh" --install-dir "${INSTALL_DIR}"; then
    echo -e "${GREEN}✓ ML Models installed successfully${NC}"
else
    echo -e "${RED}✗ ML Models installation failed${NC}"
    INSTALL_FAILED=true
fi

echo ""

# ============================================================================
# Step 4: Install LLM (Optional)
# ============================================================================
if [ "${WITH_LLM}" = "true" ]; then
    STEP_NUM=$((STEP_NUM + 1))
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  Step ${STEP_NUM}/5: Installing LLM Components${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    if "${SCRIPT_DIR}/scripts/install-slm.sh" --install-dir "${INSTALL_DIR}"; then
        echo -e "${GREEN}✓ LLM Components installed successfully${NC}"
    else
        echo -e "${RED}✗ LLM Components installation failed${NC}"
        # LLM is optional, don't fail the whole installation
        echo -e "${YELLOW}Note: LLM is optional, continuing with installation...${NC}"
    fi

    echo ""
fi

# ============================================================================
# Step 5: Verify Installation
# ============================================================================
STEP_NUM=$((STEP_NUM + 1))
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Step ${STEP_NUM}: Verifying Installation${NC}"
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
