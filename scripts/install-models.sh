#!/bin/bash
#
# Faria ML Models Installation Script
# Exports and installs DETR (layout detection) and Nemotron (table structure) models
#
# Usage: ./install-models.sh [OPTIONS]
#
# Prerequisites:
#   - Python 3.8+
#   - Git with Git LFS
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default install directory
INSTALL_DIR="${HOME}/.faria"
SKIP_DETR=false
SKIP_NEMOTRON=false
KEEP_VENV=false

# Get script directory (where this script is located)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# The repo root is the parent of scripts/
REPO_DIR="$(dirname "${SCRIPT_DIR}")"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --install-dir)
            INSTALL_DIR="$2"
            shift 2
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
        --help|-h)
            echo "Faria ML Models Installation Script"
            echo ""
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --install-dir DIR  Install to DIR (default: ~/.faria)"
            echo "  --skip-detr        Skip DETR model installation"
            echo "  --skip-nemotron    Skip Nemotron model installation"
            echo "  --keep-venv        Keep Python virtual environment after installation"
            echo "  --help, -h         Show this help message"
            echo ""
            echo "Prerequisites:"
            echo "  - Python 3.8+"
            echo "  - Git with Git LFS (for Nemotron)"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
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
echo "  Repository: ${REPO_DIR}"
echo ""

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

# Check Python (requires 3.12.x for onnxruntime compatibility)
source "${SCRIPT_DIR}/setup-python.sh"

if [ -z "${PYTHON_CMD}" ]; then
    echo -e "${RED}Error: Python 3.12 setup failed${NC}"
    exit 1
fi

PYTHON_VERSION=$($PYTHON_CMD --version 2>&1 | cut -d' ' -f2)

# Check Git
if ! command -v git &> /dev/null; then
    echo -e "${RED}Error: Git not found. Please install Git.${NC}"
    exit 1
fi
echo -e "${GREEN}  Git: $(git --version | cut -d' ' -f3)${NC}"

# Check Git LFS (required for Nemotron)
if [ "${SKIP_NEMOTRON}" = false ]; then
    if ! command -v git-lfs &> /dev/null; then
        echo -e "${RED}Error: Git LFS not found. Please install Git LFS.${NC}"
        echo ""
        echo "Installation:"
        echo "  macOS: brew install git-lfs"
        echo "  Ubuntu/Debian: sudo apt install git-lfs"
        echo "  Then run: git lfs install"
        exit 1
    fi
    echo -e "${GREEN}  Git LFS: installed${NC}"
fi

echo ""
echo -e "${YELLOW}Installation configuration:${NC}"
echo "  Install directory: ${INSTALL_DIR}"
echo "  DETR: $([ "${SKIP_DETR}" = true ] && echo "skip" || echo "install")"
echo "  Nemotron: $([ "${SKIP_NEMOTRON}" = true ] && echo "skip" || echo "install")"
echo ""

# Create directories
mkdir -p "${INSTALL_DIR}/models"

# Create temp directory for work
WORK_DIR=$(mktemp -d)
VENV_DIR="${WORK_DIR}/venv"

cleanup() {
    if [ "${KEEP_VENV}" = false ]; then
        echo -e "${YELLOW}Cleaning up temporary files...${NC}"
        rm -rf "${WORK_DIR}"
    else
        echo -e "${YELLOW}Keeping virtual environment at: ${VENV_DIR}${NC}"
    fi
}
trap cleanup EXIT

# Create virtual environment
echo -e "${YELLOW}Creating Python virtual environment...${NC}"
$PYTHON_CMD -m venv "${VENV_DIR}"
source "${VENV_DIR}/bin/activate"

# Upgrade pip
echo -e "${YELLOW}Upgrading pip...${NC}"
pip install --upgrade pip -q

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
        read -p "Do you want to reinstall? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${GREEN}Skipping DETR installation.${NC}"
            SKIP_DETR=true
        fi
    fi

    if [ "${SKIP_DETR}" = false ]; then
        echo -e "${YELLOW}Installing DETR dependencies...${NC}"
        pip install -r "${REPO_DIR}/models/requirements-detr.txt" -q

        echo -e "${YELLOW}Exporting DETR model to ONNX...${NC}"
        echo "  This may take a few minutes on first run (downloading model)..."

        # Export script is in models/ directory in this repo
        DETR_EXPORT_SCRIPT="${REPO_DIR}/models/export_detr_layout_onnx.py"

        if [ ! -f "${DETR_EXPORT_SCRIPT}" ]; then
            echo -e "${RED}Error: DETR export script not found at: ${DETR_EXPORT_SCRIPT}${NC}"
            exit 1
        fi

        cd "${WORK_DIR}"
        python "${DETR_EXPORT_SCRIPT}" --output "${DETR_MODEL_PATH}"

        if [ -f "${DETR_MODEL_PATH}" ]; then
            DETR_SIZE=$(du -h "${DETR_MODEL_PATH}" | cut -f1)
            echo -e "${GREEN}  DETR model installed: ${DETR_MODEL_PATH} (${DETR_SIZE})${NC}"
        else
            echo -e "${RED}Error: DETR ONNX file not found after export${NC}"
            echo "  Expected output: ${DETR_MODEL_PATH}"
            exit 1
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
        read -p "Do you want to reinstall? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${GREEN}Skipping Nemotron installation.${NC}"
            SKIP_NEMOTRON=true
        fi
    fi

    if [ "${SKIP_NEMOTRON}" = false ]; then
        echo -e "${YELLOW}Cloning Nemotron repository from HuggingFace...${NC}"
        echo "  This may take a while (downloading ~200MB model)..."

        NEMOTRON_REPO="${WORK_DIR}/nemotron-table-structure-v1"

        cd "${WORK_DIR}"
        git lfs install
        git clone https://huggingface.co/nvidia/nemotron-table-structure-v1 "${NEMOTRON_REPO}"

        echo -e "${YELLOW}Installing Nemotron package...${NC}"
        cd "${NEMOTRON_REPO}"
        pip install -r "${REPO_DIR}/models/requirements-nemotron.txt" -q
        pip install -e . -q

        echo -e "${YELLOW}Exporting Nemotron model to ONNX...${NC}"

        # Export script is in models/ directory in this repo
        NEMOTRON_EXPORT_SCRIPT="${REPO_DIR}/models/export_nemotron_onnx.py"

        if [ ! -f "${NEMOTRON_EXPORT_SCRIPT}" ]; then
            echo -e "${RED}Error: Nemotron export script not found at: ${NEMOTRON_EXPORT_SCRIPT}${NC}"
            exit 1
        fi

        cd "${WORK_DIR}"
        python "${NEMOTRON_EXPORT_SCRIPT}" --output "${NEMOTRON_MODEL_PATH}"

        if [ -f "${NEMOTRON_MODEL_PATH}" ]; then
            NEMOTRON_SIZE=$(du -h "${NEMOTRON_MODEL_PATH}" | cut -f1)
            echo -e "${GREEN}  Nemotron model installed: ${NEMOTRON_MODEL_PATH} (${NEMOTRON_SIZE})${NC}"
        else
            echo -e "${RED}Error: Nemotron ONNX file not found after export${NC}"
            echo "  Expected output: ${NEMOTRON_MODEL_PATH}"
            exit 1
        fi
    fi
fi

# Deactivate virtual environment
deactivate

# Verify installation
echo ""
echo -e "${YELLOW}Verifying installation...${NC}"

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
[ -f "${INSTALL_DIR}/models/detr_layout_detection.onnx" ] && echo "  ${INSTALL_DIR}/models/detr_layout_detection.onnx"
[ -f "${INSTALL_DIR}/models/nemotron_table_structure.onnx" ] && echo "  ${INSTALL_DIR}/models/nemotron_table_structure.onnx"
echo ""
echo -e "${YELLOW}Configuration Options:${NC}"
echo ""
echo "Option 1: Environment variables (recommended)"
echo "  Add these to your shell profile (~/.bashrc, ~/.zshrc, etc.):"
echo ""
echo "    export FARIA_DETR_MODEL_PATH=\"${INSTALL_DIR}/models/detr_layout_detection.onnx\""
echo "    export FARIA_NEMOTRON_MODEL_PATH=\"${INSTALL_DIR}/models/nemotron_table_structure.onnx\""
echo ""
echo "Option 2: Auto-detection"
echo "  Faria will automatically detect files in ~/.faria/ (no action needed)"
echo ""
