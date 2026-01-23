#!/bin/bash
#
# Faria Uninstallation Script
# Removes all Faria-installed files and directories
#
# Usage: ./uninstall.sh [OPTIONS]
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
            echo "Faria Uninstallation Script"
            echo ""
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --install-dir DIR  Uninstall from DIR (default: ~/.faria)"
            echo "  --force, -f        Skip confirmation prompt"
            echo "  --help, -h         Show this help message"
            echo ""
            echo "This script removes:"
            echo "  - All files in the Faria installation directory"
            echo "  - ONNX Runtime library"
            echo "  - DETR and Nemotron models"
            echo "  - llama-cli and Qwen model (if installed)"
            echo ""
            echo "Note: System-installed Tesseract OCR is NOT removed."
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Faria Uninstallation${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if installation directory exists
if [ ! -d "${INSTALL_DIR}" ]; then
    echo -e "${YELLOW}Faria installation directory not found: ${INSTALL_DIR}${NC}"
    echo "Nothing to uninstall."
    exit 0
fi

# Show what will be removed
echo -e "${YELLOW}The following will be removed:${NC}"
echo ""

# List contents
if [ -d "${INSTALL_DIR}/lib" ]; then
    echo "  Libraries:"
    find "${INSTALL_DIR}/lib" -type f 2>/dev/null | while read -r file; do
        SIZE=$(du -h "$file" 2>/dev/null | cut -f1)
        echo "    - $file ($SIZE)"
    done
fi

if [ -d "${INSTALL_DIR}/models" ]; then
    echo "  Models:"
    find "${INSTALL_DIR}/models" -type f 2>/dev/null | while read -r file; do
        SIZE=$(du -h "$file" 2>/dev/null | cut -f1)
        echo "    - $file ($SIZE)"
    done
fi

if [ -d "${INSTALL_DIR}/bin" ]; then
    echo "  Binaries:"
    find "${INSTALL_DIR}/bin" -type f 2>/dev/null | while read -r file; do
        echo "    - $file"
    done
fi

# Calculate total size
TOTAL_SIZE=$(du -sh "${INSTALL_DIR}" 2>/dev/null | cut -f1)
echo ""
echo -e "  ${YELLOW}Total: ${TOTAL_SIZE}${NC}"
echo ""

# Confirm removal
if [ "${FORCE}" = false ]; then
    echo -e "${RED}WARNING: This action cannot be undone.${NC}"
    read -p "Are you sure you want to remove all Faria files? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Uninstallation cancelled."
        exit 0
    fi
fi

# Remove files
echo ""
echo -e "${YELLOW}Removing Faria files...${NC}"

rm -rf "${INSTALL_DIR}"

# Verify removal
if [ ! -d "${INSTALL_DIR}" ]; then
    echo -e "${GREEN}✓ Faria files removed successfully${NC}"
else
    echo -e "${RED}✗ Failed to remove some files${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Uninstallation Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Removed: ${INSTALL_DIR}"
echo ""
echo -e "${YELLOW}Note:${NC} System-installed Tesseract OCR was NOT removed."
echo "To remove Tesseract, use your system's package manager:"
echo "  macOS: brew uninstall tesseract"
echo "  Ubuntu/Debian: sudo apt remove tesseract-ocr"
echo ""
echo -e "${YELLOW}Note:${NC} Remember to remove environment variables from your shell profile:"
echo "  - FARIA_ONNXRUNTIME_PATH"
echo "  - FARIA_DETR_MODEL_PATH"
echo "  - FARIA_NEMOTRON_MODEL_PATH"
echo "  - FARIA_LLAMA_CLI_PATH"
echo "  - FARIA_SLM_MODEL_PATH"
echo ""
