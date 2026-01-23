#!/bin/bash
#
# Faria Installation Verification Script
# Checks all required and optional components
# Reads version requirements from versions.json
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

# Get script directory and config path
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/../versions.json"

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

# ============================================================================
# Version checking functions
# ============================================================================

# Get minimum version from config
get_min_version() {
    local dep=$1
    if [ -f "${CONFIG_FILE}" ] && command -v jq &> /dev/null; then
        jq -r ".minimum.${dep} // \"0.0.0\"" "${CONFIG_FILE}"
    else
        echo "0.0.0"
    fi
}

# Compare versions (returns 0 if current >= min)
version_gte() {
    local current=$1
    local min=$2
    if [[ "$(printf '%s\n' "$min" "$current" | sort -V | head -n1)" == "$min" ]]; then
        return 0
    else
        return 1
    fi
}

# Check version and print result
check_version() {
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

# Check OpenCV
if pkg-config --exists opencv4 2>/dev/null; then
    OPENCV_VERSION=$(pkg-config --modversion opencv4 2>/dev/null || echo "0.0.0")
    check_version "opencv" "$OPENCV_VERSION"
else
    echo -e "  ${WARN} opencv: Not found (needed for IDP)"
    echo "     Install: brew install opencv (macOS) or apt install libopencv-dev (Linux)"
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
    exit 1
fi
echo ""
