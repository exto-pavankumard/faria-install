#!/bin/bash
#
# Faria OpenCV Installation Script
# Downloads pre-built OpenCV binaries from GitHub Releases
#
# Usage: ./install-opencv.sh [OPTIONS]
#

set -e

OPENCV_VERSION="4.12.0"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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
            echo "Faria OpenCV Installation Script"
            echo ""
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --install-dir DIR  Install to DIR (default: ~/.faria)"
            echo "  --force, -f        Reinstall even if already present"
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
echo -e "${BLUE}  Faria OpenCV Installation${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Detect OS and architecture
OS="$(uname -s)"
ARCH="$(uname -m)"

echo -e "${YELLOW}Detecting system...${NC}"
echo "  OS: ${OS}"
echo "  Architecture: ${ARCH}"

# Determine asset name based on platform
case "${OS}" in
    Darwin)
        case "${ARCH}" in
            arm64)
                OPENCV_ASSET="opencv-${OPENCV_VERSION}-macos-arm64.zip"
                ;;
            *)
                echo -e "${RED}Error: Only macOS arm64 has a pre-built OpenCV tarball.${NC}"
                echo "  For macOS x86_64, install OpenCV via Homebrew:"
                echo "    brew install opencv"
                exit 1
                ;;
        esac
        ;;
    Linux)
        case "${ARCH}" in
            x86_64)
                OPENCV_ASSET="opencv-${OPENCV_VERSION}-linux-x86_64.zip"
                ;;
            *)
                echo -e "${RED}Error: Only Linux x86_64 has a pre-built OpenCV tarball.${NC}"
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

# Asset hosted in faria-install GitHub Releases.
# Override FARIA_RELEASE_REPO to download from a fork (e.g. for CI on a fork).
RELEASE_REPO="${FARIA_RELEASE_REPO:-exto360-inc/faria-install}"
OPENCV_DIR="${INSTALL_DIR}/lib/opencv"
OPENCV_URL="https://github.com/${RELEASE_REPO}/releases/download/opencv-${OPENCV_VERSION}/${OPENCV_ASSET}"
CHECKSUMS_URL="https://github.com/${RELEASE_REPO}/releases/download/opencv-${OPENCV_VERSION}/checksums.txt"

echo ""
echo -e "${YELLOW}Installation configuration:${NC}"
echo "  Install directory: ${OPENCV_DIR}"
echo "  OpenCV version: ${OPENCV_VERSION}"
echo "  Asset: ${OPENCV_ASSET}"
echo ""

# Already installed?
if [ -f "${OPENCV_DIR}/lib/pkgconfig/opencv4.pc" ] && [ "${FORCE}" = false ]; then
    echo -e "${GREEN}OpenCV ${OPENCV_VERSION} already installed at ${OPENCV_DIR}${NC}"
    exit 0
fi

mkdir -p "${OPENCV_DIR}"

TEMP_DIR=$(mktemp -d)
trap "rm -rf '${TEMP_DIR}'" EXIT

# Download
echo -e "${YELLOW}Downloading OpenCV ${OPENCV_VERSION} pre-built tarball...${NC}"
echo "  URL: ${OPENCV_URL}"

if command -v curl &> /dev/null; then
    curl -fSL --progress-bar -o "${TEMP_DIR}/${OPENCV_ASSET}" "${OPENCV_URL}"
elif command -v wget &> /dev/null; then
    wget -q --show-progress -O "${TEMP_DIR}/${OPENCV_ASSET}" "${OPENCV_URL}"
else
    echo -e "${RED}Error: Neither curl nor wget found. Please install one.${NC}"
    exit 1
fi
echo -e "${GREEN}  Download complete.${NC}"
echo ""

# Verify checksum
echo -e "${YELLOW}Verifying checksum...${NC}"
if command -v curl &> /dev/null; then
    curl -fsSL -o "${TEMP_DIR}/checksums.txt" "${CHECKSUMS_URL}" || true
elif command -v wget &> /dev/null; then
    wget -q -O "${TEMP_DIR}/checksums.txt" "${CHECKSUMS_URL}" || true
fi

if [ -f "${TEMP_DIR}/checksums.txt" ]; then
    EXPECTED_HASH=$(grep "${OPENCV_ASSET}" "${TEMP_DIR}/checksums.txt" | awk '{print $1}')
    if [ -n "${EXPECTED_HASH}" ]; then
        if command -v sha256sum &> /dev/null; then
            ACTUAL_HASH=$(sha256sum "${TEMP_DIR}/${OPENCV_ASSET}" | awk '{print $1}')
        elif command -v shasum &> /dev/null; then
            ACTUAL_HASH=$(shasum -a 256 "${TEMP_DIR}/${OPENCV_ASSET}" | awk '{print $1}')
        else
            ACTUAL_HASH=""
        fi
        if [ -n "${ACTUAL_HASH}" ]; then
            if [ "${ACTUAL_HASH}" = "${EXPECTED_HASH}" ]; then
                echo -e "${GREEN}  Checksum OK.${NC}"
            else
                echo -e "${RED}  Checksum mismatch!${NC}"
                echo "    Expected: ${EXPECTED_HASH}"
                echo "    Got:      ${ACTUAL_HASH}"
                exit 1
            fi
        else
            echo -e "${YELLOW}  Warning: no checksum tool found — skipping verify.${NC}"
        fi
    else
        echo -e "${YELLOW}  Warning: no checksum entry found for ${OPENCV_ASSET} — skipping verify.${NC}"
    fi
fi
echo ""

# Extract
echo -e "${YELLOW}Extracting OpenCV...${NC}"
if ! command -v unzip &> /dev/null; then
    echo -e "${RED}Error: unzip not found. Install it (e.g. sudo apt install unzip) and retry.${NC}"
    exit 1
fi
EXTRACT_DIR="${TEMP_DIR}/opencv-extract"
mkdir -p "${EXTRACT_DIR}"
unzip -q "${TEMP_DIR}/${OPENCV_ASSET}" -d "${EXTRACT_DIR}"

# Handle both flat and single-wrapper-dir zips
ROOT_DIRS=$(find "${EXTRACT_DIR}" -maxdepth 1 -mindepth 1 -type d | wc -l | tr -d ' ')
ROOT_FILES=$(find "${EXTRACT_DIR}" -maxdepth 1 -mindepth 1 -type f | wc -l | tr -d ' ')
if [ "${ROOT_DIRS}" -eq 1 ] && [ "${ROOT_FILES}" -eq 0 ]; then
    WRAPPER=$(find "${EXTRACT_DIR}" -maxdepth 1 -mindepth 1 -type d | head -1)
    rm -rf "${OPENCV_DIR}"
    mv "${WRAPPER}" "${OPENCV_DIR}"
else
    rm -rf "${OPENCV_DIR}"
    mv "${EXTRACT_DIR}" "${OPENCV_DIR}"
fi
echo -e "${GREEN}  Extracted to: ${OPENCV_DIR}${NC}"
echo ""

# Fix prefix in opencv4.pc
PC_FILE="${OPENCV_DIR}/lib/pkgconfig/opencv4.pc"
if [ -f "${PC_FILE}" ]; then
    echo -e "${YELLOW}Registering opencv4.pc with pkg-config...${NC}"
    sed -i.bak "s|^prefix=.*|prefix=${OPENCV_DIR}|" "${PC_FILE}"
    rm -f "${PC_FILE}.bak"
    echo -e "${GREEN}  opencv4.pc prefix updated to ${OPENCV_DIR}.${NC}"
else
    echo -e "${YELLOW}  Warning: opencv4.pc not found — pkg-config path not registered.${NC}"
fi
echo ""

# Export PKG_CONFIG_PATH for the current session
PKG_CONFIG_DIR="${OPENCV_DIR}/lib/pkgconfig"
export PKG_CONFIG_PATH="${PKG_CONFIG_DIR}:${PKG_CONFIG_PATH:-}"

# Verify installation
echo -e "${YELLOW}Verifying installation...${NC}"

LIB_CHECK=""
case "${OS}" in
    Darwin) LIB_CHECK=$(find "${OPENCV_DIR}/lib" -maxdepth 2 -name "libopencv_core*.dylib" 2>/dev/null | head -1) ;;
    Linux)  LIB_CHECK=$(find "${OPENCV_DIR}/lib" -maxdepth 2 -name "libopencv_core*.so*"   2>/dev/null | head -1) ;;
esac

if [ -n "${LIB_CHECK}" ]; then
    echo -e "${GREEN}  OpenCV lib: $(basename "${LIB_CHECK}")${NC}"
else
    echo -e "${YELLOW}  Warning: libopencv_core not found under ${OPENCV_DIR}/lib${NC}"
fi

if pkg-config --exists opencv4 2>/dev/null; then
    OPENCV_FOUND_VER=$(pkg-config --modversion opencv4)
    echo -e "${GREEN}  pkg-config opencv4: OK (v${OPENCV_FOUND_VER})${NC}"
else
    echo -e "${YELLOW}  pkg-config opencv4: not found in current session (open a new shell or source your profile)${NC}"
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Installation Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Installed to: ${OPENCV_DIR}"
echo ""
echo "Add this to your shell profile (~/.bashrc, ~/.zshrc, etc.):"
echo ""
echo "  export PKG_CONFIG_PATH=\"${PKG_CONFIG_DIR}:\$PKG_CONFIG_PATH\""
echo ""
