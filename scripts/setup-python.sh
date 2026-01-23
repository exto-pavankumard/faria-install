#!/bin/bash
#
# Faria Python Setup Script
# Ensures Python 3.12.x is available (required for onnxruntime compatibility)
#
# Usage: source ./setup-python.sh
#   Sets PYTHON_CMD to the path of a compatible Python interpreter
#
# Or: ./setup-python.sh
#   Prints the path to the Python interpreter
#

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Detect OS
OS="$(uname -s)"

# Required Python version
REQUIRED_MAJOR=3
REQUIRED_MINOR=12

check_python_version() {
    local python_bin="$1"
    if [ ! -x "$python_bin" ] && ! command -v "$python_bin" &> /dev/null; then
        return 1
    fi

    local version=$("$python_bin" --version 2>&1 | cut -d' ' -f2)
    local major=$(echo "$version" | cut -d'.' -f1)
    local minor=$(echo "$version" | cut -d'.' -f2)

    if [ "$major" = "$REQUIRED_MAJOR" ] && [ "$minor" = "$REQUIRED_MINOR" ]; then
        echo "$version"
        return 0
    fi
    return 1
}

find_compatible_python() {
    # Check common Python 3.12 paths
    local candidates=(
        "python3.12"
        "python3"
        "python"
        "/opt/homebrew/bin/python3.12"
        "/usr/local/bin/python3.12"
        "/usr/bin/python3.12"
    )

    for candidate in "${candidates[@]}"; do
        if version=$(check_python_version "$candidate"); then
            if command -v "$candidate" &> /dev/null; then
                echo "$(command -v "$candidate")"
            else
                echo "$candidate"
            fi
            return 0
        fi
    done

    return 1
}

setup_pyenv() {
    echo -e "${YELLOW}Setting up Python ${REQUIRED_MAJOR}.${REQUIRED_MINOR} via pyenv...${NC}" >&2

    # Check if pyenv is installed
    if ! command -v pyenv &> /dev/null; then
        echo -e "${YELLOW}pyenv not found. Installing pyenv...${NC}" >&2

        if [ "$OS" = "Darwin" ]; then
            if command -v brew &> /dev/null; then
                brew install pyenv
            else
                echo -e "${RED}Error: Homebrew not found. Please install Homebrew first:${NC}" >&2
                echo "  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"" >&2
                exit 1
            fi
        else
            # Linux
            echo -e "${YELLOW}Installing pyenv via pyenv-installer...${NC}" >&2
            curl https://pyenv.run | bash

            # Add to current shell
            export PYENV_ROOT="$HOME/.pyenv"
            export PATH="$PYENV_ROOT/bin:$PATH"
        fi
    fi

    # Initialize pyenv for this shell
    export PYENV_ROOT="${PYENV_ROOT:-$HOME/.pyenv}"
    export PATH="$PYENV_ROOT/bin:$PATH"

    if command -v pyenv &> /dev/null; then
        eval "$(pyenv init -)"
    else
        echo -e "${RED}Error: pyenv installation failed.${NC}" >&2
        exit 1
    fi

    # Check if Python 3.12 is already installed via pyenv
    local pyenv_312_version=$(pyenv versions --bare 2>/dev/null | grep "^${REQUIRED_MAJOR}\.${REQUIRED_MINOR}\." | tail -1)

    if [ -z "$pyenv_312_version" ]; then
        echo -e "${YELLOW}Installing Python ${REQUIRED_MAJOR}.${REQUIRED_MINOR} via pyenv...${NC}" >&2
        echo "  This may take several minutes..." >&2

        # Find latest 3.12.x version available
        local latest_312=$(pyenv install --list 2>/dev/null | grep -E "^\s*${REQUIRED_MAJOR}\.${REQUIRED_MINOR}\.[0-9]+$" | tail -1 | tr -d ' ')

        if [ -z "$latest_312" ]; then
            echo -e "${RED}Error: Could not find Python ${REQUIRED_MAJOR}.${REQUIRED_MINOR}.x in pyenv.${NC}" >&2
            echo "  Try running: pyenv install --list | grep ${REQUIRED_MAJOR}.${REQUIRED_MINOR}" >&2
            exit 1
        fi

        pyenv install "$latest_312"
        pyenv_312_version="$latest_312"
    fi

    echo -e "${GREEN}Using pyenv Python: ${pyenv_312_version}${NC}" >&2

    # Return the full path to the Python binary
    echo "$(pyenv root)/versions/${pyenv_312_version}/bin/python3"
}

# Main logic
echo -e "${YELLOW}Checking Python version...${NC}" >&2

# First try to find a compatible Python
if python_path=$(find_compatible_python); then
    version=$(check_python_version "$python_path")
    echo -e "${GREEN}Found Python ${version} at: ${python_path}${NC}" >&2
    PYTHON_CMD="$python_path"
else
    # Check what version we have
    if command -v python3 &> /dev/null; then
        current_version=$(python3 --version 2>&1 | cut -d' ' -f2)
        echo -e "${YELLOW}System Python is ${current_version} (need ${REQUIRED_MAJOR}.${REQUIRED_MINOR}.x for onnxruntime)${NC}" >&2
    else
        echo -e "${YELLOW}No Python found${NC}" >&2
    fi

    # Use pyenv to get the right version
    PYTHON_CMD=$(setup_pyenv)
fi

# If sourced, export the variable; if run directly, print the path
if [ -n "$PYTHON_CMD" ]; then
    # Export for sourcing
    export PYTHON_CMD

    # Print path if run directly (not sourced)
    if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
        echo "$PYTHON_CMD"
    fi
else
    echo -e "${RED}Error: Could not find or install Python ${REQUIRED_MAJOR}.${REQUIRED_MINOR}${NC}" >&2
    exit 1
fi
