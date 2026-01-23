#!/bin/bash
#
# Faria OpenCV Installation Script
# Installs OpenCV for image processing
#
# Usage: ./install-opencv.sh [OPTIONS]
#
# This script uses system package managers to install OpenCV.
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
            echo "Faria OpenCV Installation Script"
            echo ""
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --help, -h         Show this help message"
            echo ""
            echo "This script installs OpenCV using your system's package manager."
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
echo -e "${BLUE}  Faria OpenCV Installation${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Detect OS and architecture
OS="$(uname -s)"

echo -e "${YELLOW}Detecting system...${NC}"
echo "  OS: ${OS}"

# Check if OpenCV is already installed
if pkg-config --exists opencv4 2>/dev/null; then
    OPENCV_VERSION=$(pkg-config --modversion opencv4)
    echo ""
    echo -e "${GREEN}OpenCV is already installed:${NC}"
    echo "  Version: ${OPENCV_VERSION}"
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

        brew install opencv
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
                sudo apt install -y libopencv-dev
                ;;
            fedora|rhel|centos|rocky|almalinux)
                echo -e "${YELLOW}Installing via dnf...${NC}"
                sudo dnf install -y opencv opencv-devel
                ;;
            arch|manjaro|endeavouros)
                echo -e "${YELLOW}Installing via pacman...${NC}"
                sudo pacman -S --noconfirm opencv
                ;;
            opensuse*)
                echo -e "${YELLOW}Installing via zypper...${NC}"
                sudo zypper install -y opencv opencv-devel
                ;;
            *)
                echo -e "${RED}Unsupported Linux distribution: ${DISTRO}${NC}"
                echo ""
                echo "Please install OpenCV manually:"
                echo "  - Ubuntu/Debian: sudo apt install libopencv-dev"
                echo "  - Fedora/RHEL: sudo dnf install opencv opencv-devel"
                echo "  - Arch: sudo pacman -S opencv"
                exit 1
                ;;
        esac
        ;;
    *)
        echo -e "${RED}Unsupported OS: ${OS}${NC}"
        echo "For Windows, please use install-opencv.ps1"
        exit 1
        ;;
esac

# Verify installation
echo ""
echo -e "${YELLOW}Verifying installation...${NC}"

if pkg-config --exists opencv4 2>/dev/null; then
    OPENCV_VERSION=$(pkg-config --modversion opencv4)
    echo -e "${GREEN}  OpenCV: OK${NC}"
    echo "    Version: ${OPENCV_VERSION}"
else
    echo -e "${RED}  OpenCV: FAILED${NC}"
    echo "  pkg-config could not find opencv4"
    exit 1
fi

# Print success message
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Installation Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "OpenCV has been installed system-wide."
echo "No additional configuration is required - Faria will auto-detect it."
echo ""
