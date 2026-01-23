#!/bin/bash
#
# Faria Chat Installation Script
# Orchestrates installation of Chat feature dependencies:
#   - llama.cpp (LLM inference engine)
#   - Qwen 2.5 model (language model)
#
# Usage: ./install-chat.sh [OPTIONS]
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

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --install-dir)
            INSTALL_DIR="$2"
            shift 2
            ;;
        --help|-h)
            echo "Faria Chat Installation Script"
            echo ""
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --install-dir DIR  Install to DIR (default: ~/.faria)"
            echo "  --help, -h         Show this help message"
            echo ""
            echo "This script installs dependencies for the Chat feature:"
            echo "  - llama.cpp        LLM inference engine (~5 MB)"
            echo "  - Qwen 2.5-0.5B    Language model (~530 MB)"
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
echo -e "${CYAN}║${NC}   ${BLUE}Faria Chat Dependencies Installation${NC}                       ${CYAN}║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${YELLOW}Install directory:${NC} ${INSTALL_DIR}"
echo ""

# Create install directory
mkdir -p "${INSTALL_DIR}"

# Track installation status
INSTALL_FAILED=false

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Installing LLM Components (llama.cpp + Qwen)${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if "${SCRIPT_DIR}/install-slm.sh" --install-dir "${INSTALL_DIR}"; then
    echo -e "${GREEN}✓ LLM Components installed successfully${NC}"
else
    echo -e "${RED}✗ LLM Components installation failed${NC}"
    INSTALL_FAILED=true
fi

# Final Summary
echo ""
echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
if [ "${INSTALL_FAILED}" = false ]; then
    echo -e "${CYAN}║${NC}   ${GREEN}Chat Dependencies Installed Successfully!${NC}                  ${CYAN}║${NC}"
else
    echo -e "${CYAN}║${NC}   ${YELLOW}Chat Installation Completed with Warnings${NC}                  ${CYAN}║${NC}"
fi
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${YELLOW}Installed components:${NC}"
echo "  • llama.cpp    - LLM inference engine"
echo "  • Qwen 2.5     - Language model for chat and cross-page table merging"
echo ""

if [ "${INSTALL_FAILED}" = true ]; then
    exit 1
fi
