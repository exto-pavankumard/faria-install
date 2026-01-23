#!/bin/bash
#
# Faria Tesseract OCR Installation Script
# Installs Tesseract OCR and Leptonica for text extraction
#
# Usage: ./install-tesseract.sh [OPTIONS]
#
# This script uses system package managers to install Tesseract.
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
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
    read -p "Do you want to reinstall/upgrade? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${GREEN}Skipping installation.${NC}"
        exit 0
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
            exit 1
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
                exit 1
                ;;
        esac
        ;;
    *)
        echo -e "${RED}Unsupported OS: ${OS}${NC}"
        echo "For Windows, please use install-tesseract.ps1"
        exit 1
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
    exit 1
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
