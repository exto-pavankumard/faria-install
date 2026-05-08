#!/bin/bash
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
INSTALL_LLM=false
SYSTEM_FLAG=""

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------------------------------------------------------------------------
# Curl-aware bootstrap — same pattern as install.sh.
# install-idp.sh's leaf scripts are siblings (no scripts/ subdir), so
# the bootstrap downloads them flat into the temp directory.
# ---------------------------------------------------------------------------
_REMOTE_BASE="${FARIA_INSTALL_RAW:-https://raw.githubusercontent.com/exto360-inc/faria-install/main}/scripts"
_BOOTSTRAP_TMPDIR=""

_bootstrap_scripts() {
    if [ ! -f "${SCRIPT_DIR}/install-opencv.sh" ]; then
        echo "Bootstrapping: downloading leaf scripts from ${_REMOTE_BASE} ..."
        _BOOTSTRAP_TMPDIR=$(mktemp -d)

        # Detect download tool
        if command -v curl &> /dev/null; then
            _dl() { curl -fsSL "$1" -o "$2"; }
        elif command -v wget &> /dev/null; then
            _dl() { wget -qO "$2" "$1"; }
        else
            echo "Error: neither curl nor wget found. Please install one and retry."
            exit 1
        fi

        # setup-python.sh needed by install-models.sh local mode;
        # install-slm.sh needed when --with-llm is used
        for s in install-opencv.sh install-tesseract.sh install-mupdf.sh \
                  install-onnxruntime.sh install-models.sh install-slm.sh setup-python.sh; do
            if ! _dl "${_REMOTE_BASE}/${s}" "${_BOOTSTRAP_TMPDIR}/${s}"; then
                echo "Error: failed to download ${s} from ${_REMOTE_BASE}"
                exit 1
            fi
            chmod +x "${_BOOTSTRAP_TMPDIR}/${s}" 2>/dev/null || true
        done
        SCRIPT_DIR="${_BOOTSTRAP_TMPDIR}"
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
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
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
run_step() {
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
run_step "Installing OpenCV" "install-opencv.sh"

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
    exit 1
fi
