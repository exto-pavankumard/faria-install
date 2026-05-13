#!/bin/bash
#
# Faria OpenCV Installation Script
# Tries to download pre-built binaries from GitHub Releases first.
# Falls back to building from source if the download fails or the
# binary cannot be verified.
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

OS="$(uname -s)"
ARCH="$(uname -m)"

echo -e "${YELLOW}Detecting system...${NC}"
echo "  OS: ${OS}"
echo "  Architecture: ${ARCH}"

case "${OS}" in
    Darwin|Linux) ;;
    *)
        echo -e "${RED}Unsupported OS: ${OS}${NC}"
        echo "For Windows, please use install-opencv.ps1"
        exit 1
        ;;
esac

# Pick release asset; leave empty when no pre-built exists for this platform.
# An empty OPENCV_ASSET causes _try_release to skip straight to fallback.
case "${OS}-${ARCH}" in
    Linux-x86_64)  OPENCV_ASSET="opencv-${OPENCV_VERSION}-linux-x86_64.zip" ;;
    Darwin-arm64)  OPENCV_ASSET="opencv-${OPENCV_VERSION}-macos-arm64.zip"  ;;
    *)             OPENCV_ASSET=""  ;;
esac

RELEASE_REPO="${FARIA_RELEASE_REPO:-exto360-inc/faria-install}"
OPENCV_DIR="${INSTALL_DIR}/lib/opencv"
OPENCV_URL="https://github.com/${RELEASE_REPO}/releases/download/opencv-${OPENCV_VERSION}/${OPENCV_ASSET}"
CHECKSUMS_URL="https://github.com/${RELEASE_REPO}/releases/download/opencv-${OPENCV_VERSION}/checksums.txt"

echo ""
echo -e "${YELLOW}Installation configuration:${NC}"
echo "  Install directory: ${OPENCV_DIR}"
echo "  OpenCV version:    ${OPENCV_VERSION}"
echo ""

# Already installed? Also accept a system/brew install visible via pkg-config.
if [ "${FORCE}" = false ]; then
    if [ -f "${OPENCV_DIR}/lib/pkgconfig/opencv4.pc" ]; then
        echo -e "${GREEN}OpenCV ${OPENCV_VERSION} already installed at ${OPENCV_DIR}${NC}"
        exit 0
    elif pkg-config --exists opencv4 2>/dev/null; then
        VER=$(pkg-config --modversion opencv4 2>/dev/null)
        echo -e "${GREEN}OpenCV already available via pkg-config (v${VER}) — skipping installation.${NC}"
        exit 0
    fi
fi

mkdir -p "${OPENCV_DIR}"

TEMP_DIR=$(mktemp -d)
trap "rm -rf '${TEMP_DIR}'" EXIT

# ============================================================================
# _try_release: attempt pre-built download.
#
# NOTE: bash disables set -e for the entire body of a function called as the
# condition of an `if` statement. Each critical step must use `|| return 1`
# so that a failure causes the function to return non-zero for the caller.
# ============================================================================
_try_release() {
    if [ -z "${OPENCV_ASSET}" ]; then
        echo -e "${YELLOW}  No pre-built release for ${OS}/${ARCH} — will build from source.${NC}"
        return 1
    fi

    echo "  Asset: ${OPENCV_ASSET}"
    echo ""

    # --- Download ---
    echo -e "${YELLOW}Downloading OpenCV ${OPENCV_VERSION} pre-built tarball...${NC}"
    echo "  URL: ${OPENCV_URL}"
    if command -v curl &>/dev/null; then
        curl -fSL --progress-bar -o "${TEMP_DIR}/${OPENCV_ASSET}" "${OPENCV_URL}" || \
            { echo -e "${YELLOW}  Download failed.${NC}"; return 1; }
    elif command -v wget &>/dev/null; then
        wget -q --show-progress -O "${TEMP_DIR}/${OPENCV_ASSET}" "${OPENCV_URL}" || \
            { echo -e "${YELLOW}  Download failed.${NC}"; return 1; }
    else
        echo -e "${YELLOW}  Neither curl nor wget found.${NC}"; return 1
    fi

    # Sanity-check: a valid pre-built zip should be at least 5 MB
    local file_size
    file_size=$(wc -c < "${TEMP_DIR}/${OPENCV_ASSET}" | tr -d ' ')
    if [ "${file_size}" -lt 5242880 ]; then
        echo -e "${YELLOW}  Downloaded file is only ${file_size} bytes — not a valid binary release.${NC}"
        return 1
    fi
    echo -e "${GREEN}  Download complete.${NC}"
    echo ""

    # --- Checksum ---
    echo -e "${YELLOW}Verifying checksum...${NC}"
    if command -v curl &>/dev/null; then
        curl -fsSL -o "${TEMP_DIR}/checksums.txt" "${CHECKSUMS_URL}" 2>/dev/null || true
    else
        wget -q -O "${TEMP_DIR}/checksums.txt" "${CHECKSUMS_URL}" 2>/dev/null || true
    fi
    if [ -f "${TEMP_DIR}/checksums.txt" ]; then
        local expected actual
        expected=$(grep "${OPENCV_ASSET}" "${TEMP_DIR}/checksums.txt" | awk '{print $1}')
        if [ -n "${expected}" ]; then
            if command -v sha256sum &>/dev/null; then
                actual=$(sha256sum "${TEMP_DIR}/${OPENCV_ASSET}" | awk '{print $1}')
            elif command -v shasum &>/dev/null; then
                actual=$(shasum -a 256 "${TEMP_DIR}/${OPENCV_ASSET}" | awk '{print $1}')
            fi
            if [ -n "${actual}" ] && [ "${actual}" != "${expected}" ]; then
                echo -e "${YELLOW}  Checksum mismatch — release binary may be corrupt.${NC}"
                return 1
            fi
            [ -n "${actual}" ] && echo -e "${GREEN}  Checksum OK.${NC}"
        else
            echo -e "${YELLOW}  No checksum entry for ${OPENCV_ASSET} — skipping verify.${NC}"
        fi
    fi
    echo ""

    # --- Extract ---
    echo -e "${YELLOW}Extracting OpenCV...${NC}"
    if ! command -v unzip &>/dev/null; then
        echo -e "${YELLOW}  unzip not found — cannot use pre-built archive.${NC}"
        return 1
    fi
    local extract_dir="${TEMP_DIR}/opencv-extract"
    mkdir -p "${extract_dir}"
    unzip -q "${TEMP_DIR}/${OPENCV_ASSET}" -d "${extract_dir}" || \
        { echo -e "${YELLOW}  Extraction failed.${NC}"; return 1; }

    local root_dirs root_files
    root_dirs=$(find "${extract_dir}" -maxdepth 1 -mindepth 1 -type d | wc -l | tr -d ' ')
    root_files=$(find "${extract_dir}" -maxdepth 1 -mindepth 1 -type f | wc -l | tr -d ' ')
    if [ "${root_dirs}" -eq 1 ] && [ "${root_files}" -eq 0 ]; then
        local wrapper
        wrapper=$(find "${extract_dir}" -maxdepth 1 -mindepth 1 -type d | head -1)
        rm -rf "${OPENCV_DIR}"
        mv "${wrapper}" "${OPENCV_DIR}"
    else
        rm -rf "${OPENCV_DIR}"
        mv "${extract_dir}" "${OPENCV_DIR}"
    fi
    echo -e "${GREEN}  Extracted to: ${OPENCV_DIR}${NC}"
    echo ""

    # Sanity-check: archive must contain opencv4.pc
    if [ ! -f "${OPENCV_DIR}/lib/pkgconfig/opencv4.pc" ]; then
        echo -e "${YELLOW}  opencv4.pc missing from archive — binary may be incomplete.${NC}"
        return 1
    fi

    # Fix prefix in opencv4.pc
    echo -e "${YELLOW}Registering opencv4.pc with pkg-config...${NC}"
    sed -i.bak "s|^prefix=.*|prefix=${OPENCV_DIR}|" "${OPENCV_DIR}/lib/pkgconfig/opencv4.pc"
    rm -f "${OPENCV_DIR}/lib/pkgconfig/opencv4.pc.bak"
    echo -e "${GREEN}  opencv4.pc prefix updated to ${OPENCV_DIR}.${NC}"
    echo ""

    return 0
}

# ============================================================================
# _build_from_source: build OpenCV from source.
# Called outside an `if` condition, so set -e applies normally.
# ============================================================================
_build_from_source() {
    echo -e "${YELLOW}Building OpenCV ${OPENCV_VERSION} from source...${NC}"
    echo ""

    case "${OS}" in
        Darwin)
            if ! command -v brew &>/dev/null; then
                echo -e "${RED}Error: Homebrew is not installed.${NC}"
                echo "Install it from https://brew.sh then re-run this script."
                exit 1
            fi
            echo -e "${YELLOW}Installing via Homebrew (this may take several minutes)...${NC}"
            brew install opencv
            # Redirect OPENCV_DIR to the brew prefix so pkg-config resolution works
            OPENCV_DIR="$(brew --prefix opencv)"
            ;;

        Linux)
            local distro=""
            [ -f /etc/os-release ] && { . /etc/os-release; distro="${ID}"; }
            echo "  Distribution: ${distro:-unknown}"
            echo ""

            echo -e "${YELLOW}Installing build dependencies...${NC}"
            case "${distro}" in
                ubuntu|debian|linuxmint|pop)
                    sudo apt-get update -q
                    sudo apt-get install -y --no-install-recommends \
                        build-essential cmake pkg-config unzip \
                        libjpeg-dev libpng-dev libtiff-dev
                    ;;
                fedora|rhel|centos|rocky|almalinux)
                    sudo dnf install -y gcc gcc-c++ cmake pkgconfig unzip \
                        libjpeg-turbo-devel libpng-devel libtiff-devel
                    ;;
                arch|manjaro|endeavouros)
                    sudo pacman -S --noconfirm base-devel cmake pkgconf unzip \
                        libjpeg-turbo libpng libtiff
                    ;;
                opensuse*)
                    sudo zypper install -y gcc gcc-c++ cmake pkg-config unzip \
                        libjpeg62-devel libpng16-devel libtiff-devel
                    ;;
                *)
                    echo -e "${YELLOW}  Unknown distro — skipping automatic dependency install.${NC}"
                    echo "  Ensure cmake, gcc, and image codec dev libs are installed."
                    ;;
            esac
            echo ""

            # Download source
            local src_url="https://github.com/opencv/opencv/archive/refs/tags/${OPENCV_VERSION}.tar.gz"
            echo -e "${YELLOW}Downloading OpenCV ${OPENCV_VERSION} source...${NC}"
            if command -v curl &>/dev/null; then
                curl -fSL --progress-bar -o "${TEMP_DIR}/opencv.tar.gz" "${src_url}"
            else
                wget -q --show-progress -O "${TEMP_DIR}/opencv.tar.gz" "${src_url}"
            fi
            tar -xzf "${TEMP_DIR}/opencv.tar.gz" -C "${TEMP_DIR}"
            echo ""

            # Build and install to OPENCV_DIR (no sudo needed — user-space dir)
            local jobs
            jobs=$(nproc 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null || echo 2)
            echo -e "${YELLOW}Building OpenCV ${OPENCV_VERSION} (${jobs} jobs — this may take 10-20 minutes)...${NC}"
            cmake "${TEMP_DIR}/opencv-${OPENCV_VERSION}" \
                -B "${TEMP_DIR}/opencv_build" \
                -DCMAKE_BUILD_TYPE=Release \
                -DCMAKE_INSTALL_PREFIX="${OPENCV_DIR}" \
                -DOPENCV_GENERATE_PKGCONFIG=ON \
                -DBUILD_LIST=core,imgproc,imgcodecs,objdetect,features2d,photo,calib3d,video,videoio,dnn,highgui \
                -DBUILD_TESTS=OFF -DBUILD_PERF_TESTS=OFF -DBUILD_EXAMPLES=OFF \
                -DBUILD_SHARED_LIBS=ON \
                -DBUILD_JPEG=ON -DBUILD_PNG=ON -DBUILD_TIFF=ON \
                -DWITH_GTK=OFF -DWITH_QT=OFF -DWITH_OPENGL=OFF \
                -DWITH_FFMPEG=OFF -DWITH_GSTREAMER=OFF -DWITH_V4L=OFF \
                -DWITH_IPP=OFF -DBUILD_PROTOBUF=ON -DWITH_PROTOBUF=ON \
                -DWITH_JASPER=OFF -DWITH_OPENEXR=OFF
            cmake --build "${TEMP_DIR}/opencv_build" --parallel "${jobs}"
            cmake --install "${TEMP_DIR}/opencv_build"
            echo -e "${GREEN}  Source build complete.${NC}"
            echo ""
            ;;
    esac
}

# ============================================================================
# Main: try release, fall back to source on any failure
# ============================================================================
INSTALL_METHOD=""

if _try_release; then
    INSTALL_METHOD="pre-built release"
else
    echo -e "${YELLOW}Pre-built release unavailable or failed — falling back to build from source.${NC}"
    echo ""
    _build_from_source
    INSTALL_METHOD="source build"
fi

# ============================================================================
# PKG_CONFIG_PATH — resolve after potential OPENCV_DIR update (brew changes it)
# ============================================================================
PKG_CONFIG_DIR="${OPENCV_DIR}/lib/pkgconfig"
export PKG_CONFIG_PATH="${PKG_CONFIG_DIR}:${PKG_CONFIG_PATH:-}"

# ============================================================================
# Verify
# ============================================================================
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
echo "Method:       ${INSTALL_METHOD}"
echo ""
echo "Add this to your shell profile (~/.bashrc, ~/.zshrc, etc.):"
echo ""
echo "  export PKG_CONFIG_PATH=\"${PKG_CONFIG_DIR}:\$PKG_CONFIG_PATH\""
echo ""
