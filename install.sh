#!/bin/bash
#
# Faria Installation Script
# Main orchestration script for installing Faria dependencies
#
# Usage: ./install.sh [OPTIONS]
#
# Features:
#   idp  - Intelligent Document Processing (OpenCV, Tesseract, MuPDF, ONNX, models)
#   chat - Conversational AI (llama.cpp, Qwen model)
#
# Examples:
#   ./install.sh --features idp          # Install IDP only
#   ./install.sh --features chat         # Install Chat only
#   ./install.sh --features idp,chat     # Install both
#   ./install.sh --features all          # Install everything
#   ./install.sh                         # Interactive mode
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
FEATURES=""  # Empty means prompt, comma-separated list of features
SYSTEM_FLAG=""

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------------------------------------------------------------------------
# Curl-aware bootstrap
# When run via `curl | bash`, BASH_SOURCE[0] is not the repo path so
# sub-scripts are not found at ${SCRIPT_DIR}/scripts/. Detect this and
# download them to a temp directory instead.
#
# FARIA_INSTALL_RAW must point to the repo root (no /scripts suffix).
# The bootstrap appends /scripts internally.
# ---------------------------------------------------------------------------
_REMOTE_BASE="${FARIA_INSTALL_RAW:-https://raw.githubusercontent.com/exto360-inc/faria-install/main}/scripts"
_BOOTSTRAP_TMPDIR=""

_bootstrap_scripts() {
    if [ ! -f "${SCRIPT_DIR}/scripts/install-idp.sh" ]; then
        echo "Bootstrapping: downloading sub-scripts from ${_REMOTE_BASE} ..."
        _BOOTSTRAP_TMPDIR=$(mktemp -d)
        mkdir -p "${_BOOTSTRAP_TMPDIR}/scripts"

        # Detect download tool
        if command -v curl &> /dev/null; then
            _dl() { curl -fsSL "$1" -o "$2"; }
        elif command -v wget &> /dev/null; then
            _dl() { wget -qO "$2" "$1"; }
        else
            echo "Error: neither curl nor wget found. Please install one and retry."
            exit 1
        fi

        # Download sub-scripts (setup-python.sh needed by install-models.sh local mode;
        # install-slm.sh needed when --with-llm is used)
        for s in install-idp.sh install-opencv.sh install-tesseract.sh \
                  install-mupdf.sh install-onnxruntime.sh install-models.sh \
                  install-chat.sh install-slm.sh verify.sh setup-python.sh; do
            if ! _dl "${_REMOTE_BASE}/${s}" "${_BOOTSTRAP_TMPDIR}/scripts/${s}"; then
                echo "Error: failed to download ${s} from ${_REMOTE_BASE}"
                exit 1
            fi
            chmod +x "${_BOOTSTRAP_TMPDIR}/scripts/${s}" 2>/dev/null || true
        done

        # Download versions.json (needed by verify.sh which looks at ../versions.json)
        _REMOTE_ROOT="${FARIA_INSTALL_RAW:-https://raw.githubusercontent.com/exto360-inc/faria-install/main}"
        if ! _dl "${_REMOTE_ROOT}/versions.json" "${_BOOTSTRAP_TMPDIR}/versions.json"; then
            echo "Error: failed to download versions.json from ${_REMOTE_ROOT}"
            exit 1
        fi

        SCRIPT_DIR="${_BOOTSTRAP_TMPDIR}"
    fi
}

# Note: trap replaces any previously-registered EXIT handler. This is intentional —
# bootstrap cleanup is the only EXIT action needed at this scope.
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
        --features)
            FEATURES="$2"
            shift 2
            ;;
        --help|-h)
            echo "Faria Installation Script"
            echo ""
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --features LIST    Comma-separated list of features to install"
            echo "                     Available: idp, chat, all"
            echo "  --install-dir DIR  Install to DIR (default: ~/.faria)"
            echo "  --gpu              Enable GPU support (CUDA on Linux)"
            echo "  --system           Install ONNX Runtime system-wide (/usr/local) with headers (for Docker/CGO builds)"
            echo "  --help, -h         Show this help message"
            echo ""
            echo "Features:"
            echo "  idp   - Intelligent Document Processing (~630 MB)"
            echo "          OpenCV, Tesseract, Leptonica, MuPDF, ONNX Runtime,"
            echo "          DETR model, Nemotron model"
            echo "          Optional: LLM support (~500 MB extra, prompted during install)"
            echo ""
            echo "  chat  - Conversational AI (~535 MB)"
            echo "          llama.cpp, Qwen 2.5 model"
            echo ""
            echo "Examples:"
            echo "  $0 --features idp           # IDP (prompts for LLM option)"
            echo "  $0 --features chat          # Chat only"
            echo "  $0 --features idp,chat      # Both features"
            echo "  $0 --features all           # Everything"
            echo "  $0                          # Interactive mode"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Banner
echo ""
echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${NC}                                                               ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}   ${BLUE}███████╗ █████╗ ██████╗ ██╗ █████╗${NC}                          ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}   ${BLUE}██╔════╝██╔══██╗██╔══██╗██║██╔══██╗${NC}                         ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}   ${BLUE}█████╗  ███████║██████╔╝██║███████║${NC}                         ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}   ${BLUE}██╔══╝  ██╔══██║██╔══██╗██║██╔══██║${NC}                         ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}   ${BLUE}██║     ██║  ██║██║  ██║██║██║  ██║${NC}                         ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}   ${BLUE}╚═╝     ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝╚═╝  ╚═╝${NC}                         ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}                                                               ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}   ${GREEN}AI Toolkit                     ${NC}                             ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}                                                               ${CYAN}║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Detect OS
OS="$(uname -s)"
ARCH="$(uname -m)"

echo -e "${YELLOW}System detected:${NC} ${OS} (${ARCH})"
echo -e "${YELLOW}Install directory:${NC} ${INSTALL_DIR}"
echo ""

# Show available features
echo -e "${BLUE}Available features:${NC}"
echo ""
echo -e "  ${GREEN}idp${NC}  - Intelligent Document Processing (~630 MB)"
echo "         OpenCV, Tesseract, Leptonica, MuPDF, ONNX Runtime,"
echo "         DETR model (layout detection), Nemotron model (tables)"
echo ""
echo -e "  ${GREEN}chat${NC} - Conversational AI (~535 MB)"
echo "         llama.cpp, Qwen 2.5 model"
echo ""

# Prompt for features if not specified
if [ -z "${FEATURES}" ]; then
    if [ ! -t 0 ]; then
        echo "Error: --features is required in non-interactive mode."
        echo "  Example: curl -fsSL ... | bash -s -- --features idp"
        exit 1
    fi
    echo -e "${YELLOW}Which features do you want to install?${NC}"
    echo ""
    echo "  1) idp only      - Document processing"
    echo "  2) chat only     - Conversational AI"
    echo "  3) idp + chat    - Both features"
    echo "  4) Cancel"
    echo ""
    read -p "Enter choice [1-4]: " -n 1 -r
    echo
    case $REPLY in
        1) FEATURES="idp" ;;
        2) FEATURES="chat" ;;
        3) FEATURES="idp,chat" ;;
        4|*)
            echo "Installation cancelled."
            exit 0
            ;;
    esac
fi

# Normalize "all" to actual features
if [ "${FEATURES}" = "all" ]; then
    FEATURES="idp,chat"
fi

# Parse features into flags
INSTALL_IDP=false
INSTALL_CHAT=false

IFS=',' read -ra FEATURE_ARRAY <<< "${FEATURES}"
for feature in "${FEATURE_ARRAY[@]}"; do
    feature=$(echo "$feature" | tr -d ' ')
    case "$feature" in
        idp) INSTALL_IDP=true ;;
        chat) INSTALL_CHAT=true ;;
        *) echo -e "${YELLOW}Warning: Unknown feature '${feature}' ignored${NC}" ;;
    esac
done

# Validate at least one feature selected
if [ "${INSTALL_IDP}" = false ] && [ "${INSTALL_CHAT}" = false ]; then
    echo -e "${RED}Error: No valid features selected${NC}"
    exit 1
fi

# Ask about LLM for IDP if IDP is selected
INSTALL_IDP_LLM=false
if [ "${INSTALL_IDP}" = true ]; then
    echo ""
    echo -e "${YELLOW}Would you like to install LLM support for IDP?${NC}"
    echo "  This enables advanced document understanding capabilities."
    echo "  (Requires additional ~500 MB disk space)"
    echo ""
    if [ -t 0 ]; then
        read -p "Install LLM for IDP? (y/N): " -n 1 -r
        echo
    else
        REPLY="N"
    fi
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        INSTALL_IDP_LLM=true
    fi
fi

echo ""
echo -e "${BLUE}Installation summary:${NC}"
echo "  • IDP (Document Processing): $([ "${INSTALL_IDP}" = true ] && echo "yes" || echo "no")"
if [ "${INSTALL_IDP}" = true ]; then
    echo "    └─ LLM support: $([ "${INSTALL_IDP_LLM}" = true ] && echo "yes" || echo "no")"
fi
echo "  • Chat (Conversational AI): $([ "${INSTALL_CHAT}" = true ] && echo "yes" || echo "no")"
if [ "${OS}" = "Darwin" ]; then
    echo "  • Core ML: yes (if IDP selected)"
else
    echo "  • GPU support: $([ "${ENABLE_GPU}" = true ] && echo "yes" || echo "no")"
fi
echo ""

if [ -t 0 ]; then
    read -p "Continue with installation? (Y/n): " -n 1 -r
    echo
else
    REPLY="Y"
fi
if [[ $REPLY =~ ^[Nn]$ ]]; then
    echo "Installation cancelled."
    exit 0
fi

echo ""

# Create install directory
mkdir -p "${INSTALL_DIR}"

# Track installation status
INSTALL_FAILED=false
CURRENT_STEP=0
TOTAL_STEPS=0

# Calculate total steps
if [ "${INSTALL_IDP}" = true ]; then
    TOTAL_STEPS=$((TOTAL_STEPS + 1))  # IDP orchestrator
fi
if [ "${INSTALL_CHAT}" = true ]; then
    TOTAL_STEPS=$((TOTAL_STEPS + 1))  # Chat orchestrator
fi
TOTAL_STEPS=$((TOTAL_STEPS + 1))  # Verification

# ============================================================================
# Install IDP Feature
# ============================================================================
if [ "${INSTALL_IDP}" = true ]; then
    CURRENT_STEP=$((CURRENT_STEP + 1))
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  Step ${CURRENT_STEP}/${TOTAL_STEPS}: Installing IDP Feature${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    GPU_FLAG=""
    if [ "${ENABLE_GPU}" = true ]; then
        GPU_FLAG="--gpu"
    fi

    LLM_FLAG=""
    if [ "${INSTALL_IDP_LLM}" = true ]; then
        LLM_FLAG="--with-llm"
    fi

    if "${SCRIPT_DIR}/scripts/install-idp.sh" --install-dir "${INSTALL_DIR}" ${GPU_FLAG} ${LLM_FLAG} ${SYSTEM_FLAG}; then
        echo -e "${GREEN}✓ IDP Feature installed successfully${NC}"
    else
        echo -e "${RED}✗ IDP Feature installation failed${NC}"
        INSTALL_FAILED=true
    fi

    echo ""
fi

# ============================================================================
# Install Chat Feature
# ============================================================================
if [ "${INSTALL_CHAT}" = true ]; then
    CURRENT_STEP=$((CURRENT_STEP + 1))
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  Step ${CURRENT_STEP}/${TOTAL_STEPS}: Installing Chat Feature${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    if "${SCRIPT_DIR}/scripts/install-chat.sh" --install-dir "${INSTALL_DIR}"; then
        echo -e "${GREEN}✓ Chat Feature installed successfully${NC}"
    else
        echo -e "${RED}✗ Chat Feature installation failed${NC}"
        INSTALL_FAILED=true
    fi

    echo ""
fi

# ============================================================================
# Verify Installation
# ============================================================================
CURRENT_STEP=$((CURRENT_STEP + 1))
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Step ${CURRENT_STEP}/${TOTAL_STEPS}: Verifying Installation${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

"${SCRIPT_DIR}/scripts/verify.sh" --install-dir "${INSTALL_DIR}" ${SYSTEM_FLAG}

# ============================================================================
# Final Summary
# ============================================================================
echo ""
echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
if [ "${INSTALL_FAILED}" = false ]; then
    echo -e "${CYAN}║${NC}                                                               ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}   ${GREEN}Installation Complete!${NC}                                      ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}                                                               ${CYAN}║${NC}"
else
    echo -e "${CYAN}║${NC}                                                               ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}   ${YELLOW}Installation completed with warnings${NC}                        ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}                                                               ${CYAN}║${NC}"
fi
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${YELLOW}Installed features:${NC}"
if [ "${INSTALL_IDP}" = true ]; then
    echo "  • IDP - OpenCV, Tesseract, MuPDF, ONNX Runtime, DETR, Nemotron"
fi
if [ "${INSTALL_CHAT}" = true ]; then
    echo "  • Chat - llama.cpp, Qwen 2.5"
fi
echo ""

echo -e "${YELLOW}Next steps:${NC}"
echo ""
echo "1. Add environment variables to your shell profile (optional):"
echo "   See the output above for the exact paths."
echo ""
echo "2. Or use auto-detection (no configuration needed):"
echo "   Faria will automatically find files in ~/.faria/"
echo ""
echo "3. Start using Faria in your Go code:"
echo ""
echo -e "   ${BLUE}config := faria.DefaultConfig()${NC}"
echo -e "   ${BLUE}client, err := faria.New(config)${NC}"
echo ""
echo "For more information, see: https://github.com/exto360-inc/faria"
echo ""
