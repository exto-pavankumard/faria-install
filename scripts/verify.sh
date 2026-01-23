#!/bin/bash
#
# Faria Installation Verification Script
# Checks all required and optional components
#
# Usage: ./verify.sh [OPTIONS]
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Symbols
CHECK="${GREEN}✓${NC}"
CROSS="${RED}✗${NC}"
WARN="${YELLOW}!${NC}"

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
            echo "Faria Installation Verification Script"
            echo ""
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --install-dir DIR  Check installation in DIR (default: ~/.faria)"
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

echo -e "${YELLOW}Checking components...${NC}"
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

# Check default location
if [ -z "${ONNX_PATH}" ] || [ ! -f "${ONNX_PATH}" ]; then
    ONNX_PATH="${INSTALL_DIR}/lib/onnxruntime/${LIB_NAME}"
fi

if [ -f "${ONNX_PATH}" ]; then
    LIB_SIZE=$(du -h "${ONNX_PATH}" | cut -f1)
    echo -e "  ${CHECK} Found (${LIB_SIZE})"
    echo "     ${ONNX_PATH}"
else
    echo -e "  ${CROSS} Not found"
    echo "     Expected: ${INSTALL_DIR}/lib/onnxruntime/${LIB_NAME}"
    ALL_REQUIRED_OK=false
    MISSING_COMPONENTS="${MISSING_COMPONENTS}ONNX Runtime, "
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
# Check Tesseract OCR
# ============================================================================
echo -e "${BLUE}Tesseract OCR:${NC}"

if command -v tesseract &> /dev/null; then
    TESSERACT_VERSION=$(tesseract --version 2>&1 | head -n1 | cut -d' ' -f2)
    TESSERACT_PATH=$(which tesseract)
    echo -e "  ${CHECK} Found (${TESSERACT_VERSION})"
    echo "     ${TESSERACT_PATH}"
else
    echo -e "  ${CROSS} Not found"
    echo "     Install: brew install tesseract (macOS) or apt install tesseract-ocr (Linux)"
    ALL_REQUIRED_OK=false
    MISSING_COMPONENTS="${MISSING_COMPONENTS}Tesseract, "
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
    exit 1
fi
echo ""
