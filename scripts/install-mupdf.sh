#!/bin/bash
#
# Faria MuPDF Installation Script
# Installs MuPDF for PDF processing
#
# Usage: ./install-mupdf.sh [OPTIONS]
#
# This script uses system package managers to install MuPDF.
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
            echo "Faria MuPDF Installation Script"
            echo ""
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --help, -h         Show this help message"
            echo ""
            echo "This script installs MuPDF using your system's package manager."
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
echo -e "${BLUE}  Faria MuPDF Installation${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Detect OS and architecture
OS="$(uname -s)"

echo -e "${YELLOW}Detecting system...${NC}"
echo "  OS: ${OS}"

# Check if MuPDF is already installed
check_mupdf_installed() {
    if command -v mutool &> /dev/null; then
        return 0
    fi
    # Check for library
    if pkg-config --exists mupdf 2>/dev/null; then
        return 0
    fi
    # macOS: check Homebrew
    if [ "${OS}" = "Darwin" ] && brew list mupdf &>/dev/null; then
        return 0
    fi
    return 1
}

if check_mupdf_installed; then
    if command -v mutool &> /dev/null; then
        MUPDF_VERSION=$(mutool -v 2>&1 | head -n1 || echo "unknown")
    else
        MUPDF_VERSION="installed (version unknown)"
    fi
    echo ""
    echo -e "${GREEN}MuPDF is already installed:${NC}"
    echo "  Version: ${MUPDF_VERSION}"
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

        brew install mupdf
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
                sudo apt install -y mupdf mupdf-tools libmupdf-dev
                ;;
            fedora|rhel|centos|rocky|almalinux)
                echo -e "${YELLOW}Installing via dnf...${NC}"
                sudo dnf install -y mupdf mupdf-devel
                ;;
            arch|manjaro|endeavouros)
                echo -e "${YELLOW}Installing via pacman...${NC}"
                sudo pacman -S --noconfirm mupdf mupdf-tools
                ;;
            opensuse*)
                echo -e "${YELLOW}Installing via zypper...${NC}"
                sudo zypper install -y mupdf mupdf-devel
                ;;
            *)
                echo -e "${RED}Unsupported Linux distribution: ${DISTRO}${NC}"
                echo ""
                echo "Please install MuPDF manually:"
                echo "  - Ubuntu/Debian: sudo apt install mupdf mupdf-tools libmupdf-dev"
                echo "  - Fedora/RHEL: sudo dnf install mupdf mupdf-devel"
                echo "  - Arch: sudo pacman -S mupdf mupdf-tools"
                exit 1
                ;;
        esac
        ;;
    *)
        echo -e "${RED}Unsupported OS: ${OS}${NC}"
        echo "For Windows, please use install-mupdf.ps1"
        exit 1
        ;;
esac

# Verify installation
echo ""
echo -e "${YELLOW}Verifying installation...${NC}"

if command -v mutool &> /dev/null; then
    MUPDF_VERSION=$(mutool -v 2>&1 | head -n1 || echo "installed")
    echo -e "${GREEN}  MuPDF: OK${NC}"
    echo "    Version: ${MUPDF_VERSION}"
else
    echo -e "${YELLOW}  MuPDF: mutool not in PATH${NC}"
    echo "    Library may still be available for linking"
fi

# Print success message
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Installation Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "MuPDF has been installed system-wide."
echo "No additional configuration is required - Faria will auto-detect it."
echo ""
