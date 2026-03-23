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

        # Distro repos ship OpenCV 4.5/4.6 which causes dependency mismatches.
        # Build 4.10.0 from source to guarantee a compatible version.
        OPENCV_BUILD_VERSION="4.10.0"

        echo -e "${YELLOW}Installing build dependencies...${NC}"
        case "${DISTRO}" in
            ubuntu|debian|linuxmint|pop)
                sudo apt update
                sudo apt install -y build-essential cmake git pkg-config \
                    libgtk-3-dev libavcodec-dev libavformat-dev libswscale-dev \
                    libv4l-dev libjpeg-dev libpng-dev libtiff-dev \
                    libatlas-base-dev python3-dev python3-numpy libtbb-dev
                ;;
            fedora|rhel|centos|rocky|almalinux)
                sudo dnf install -y gcc gcc-c++ cmake git pkgconfig \
                    gtk3-devel ffmpeg-devel libv4l-devel \
                    libjpeg-turbo-devel libpng-devel libtiff-devel \
                    python3-devel python3-numpy tbb-devel
                ;;
            arch|manjaro|endeavouros)
                sudo pacman -S --noconfirm base-devel cmake git pkg-config \
                    gtk3 ffmpeg libjpeg-turbo libpng libtiff \
                    python python-numpy intel-tbb
                ;;
            opensuse*)
                sudo zypper install -y gcc gcc-c++ cmake git pkg-config \
                    gtk3-devel ffmpeg-devel libv4l-devel \
                    libjpeg62-devel libpng16-devel libtiff-devel \
                    python3-devel python3-numpy tbb-devel
                ;;
            *)
                echo -e "${RED}Unsupported Linux distribution: ${DISTRO}${NC}"
                exit 1
                ;;
        esac

        echo ""
        echo -e "${YELLOW}Downloading OpenCV ${OPENCV_BUILD_VERSION} source...${NC}"
        BUILD_DIR="$(mktemp -d)"
        curl -fL "https://github.com/opencv/opencv/archive/refs/tags/${OPENCV_BUILD_VERSION}.tar.gz" \
            -o "${BUILD_DIR}/opencv.tar.gz"

        echo -e "${YELLOW}Building OpenCV ${OPENCV_BUILD_VERSION} (this may take 10-20 minutes)...${NC}"
        tar -xzf "${BUILD_DIR}/opencv.tar.gz" -C "${BUILD_DIR}"
        mkdir -p "${BUILD_DIR}/opencv-${OPENCV_BUILD_VERSION}/build"
        cd "${BUILD_DIR}/opencv-${OPENCV_BUILD_VERSION}/build"

        cmake .. \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_PREFIX=/usr/local \
            -DOPENCV_GENERATE_PKGCONFIG=ON \
            -DBUILD_TESTS=OFF \
            -DBUILD_PERF_TESTS=OFF \
            -DBUILD_EXAMPLES=OFF

        make -j"$(nproc)"
        sudo make install
        sudo ldconfig

        # Persist the pkg-config path so opencv4.pc is always discoverable
        echo 'export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH' \
            | sudo tee /etc/profile.d/opencv.sh > /dev/null
        export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH

        cd - > /dev/null
        rm -rf "${BUILD_DIR}"
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