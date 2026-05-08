#!/bin/bash
#
# Faria Installer Build Script
# Generates single-file installers from modular source scripts
#
# Usage: ./build/build.sh [--sh-only | --ps1-only]
#
# This script combines all modular installation scripts into single-file
# installers that can be used with curl|bash or Invoke-WebRequest|iex.
#

set -e

# Get script directory and repo root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "${SCRIPT_DIR}")"

# Output directory
DIST_DIR="${ROOT_DIR}/dist"

# Build metadata
BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
GITHUB_RAW_URL="https://raw.githubusercontent.com/exto360-inc/faria-install/main"

# ============================================================================
# Shell Script Builder
# ============================================================================

# Convert a standalone script into a function
# Args: $1 = script path, $2 = function name
convert_shell_script_to_function() {
    local script_path="$1"
    local func_name="$2"

    if [ ! -f "${script_path}" ]; then
        echo "    Warning: Script not found: ${script_path}" >&2
        return
    fi

    echo ""
    echo "# ============================================================================"
    echo "# ${func_name}() - from $(basename "${script_path}")"
    echo "# ============================================================================"
    echo "${func_name}() {"

    # Process the script with sed
    tail -n +2 "${script_path}" | \
        # Remove set -e (already at top level)
        sed '/^[[:space:]]*set[[:space:]]\{1,\}-e[[:space:]]*$/d' | \
        # Remove color definitions (already in _common.sh)
        sed '/^[[:space:]]*RED=/d' | \
        sed '/^[[:space:]]*GREEN=/d' | \
        sed '/^[[:space:]]*YELLOW=/d' | \
        sed '/^[[:space:]]*BLUE=/d' | \
        sed '/^[[:space:]]*CYAN=/d' | \
        sed '/^[[:space:]]*NC=/d' | \
        # Remove SCRIPT_DIR and REPO_DIR calculations
        sed '/^[[:space:]]*SCRIPT_DIR=/d' | \
        sed '/^[[:space:]]*REPO_DIR=/d' | \
        # Convert nested function definitions: cleanup() { -> function _local_cleanup {
        sed -E 's/^([[:space:]]*)([a-zA-Z_][a-zA-Z_0-9]*)\(\)[[:space:]]*\{/\1function _local_\2 {/g' | \
        # Update references to renamed nested functions
        sed 's/trap cleanup EXIT/trap _local_cleanup EXIT/g' | \
        # Replace source of setup-python.sh with function call
        sed 's|source.*setup-python\.sh.*|__setup_python|g' | \
        # Replace script calls with function calls (from install-idp.sh)
        sed 's|"\${SCRIPT_DIR}/install-opencv\.sh"|__install_opencv|g' | \
        sed 's|"\${SCRIPT_DIR}/install-tesseract\.sh"|__install_tesseract|g' | \
        sed 's|"\${SCRIPT_DIR}/install-mupdf\.sh"|__install_mupdf|g' | \
        sed 's|"\${SCRIPT_DIR}/install-onnxruntime\.sh"|__install_onnxruntime|g' | \
        sed 's|"\${SCRIPT_DIR}/install-models\.sh"|__install_models|g' | \
        sed 's|"\${SCRIPT_DIR}/install-slm\.sh"|__install_slm|g' | \
        sed 's|"\${SCRIPT_DIR}/install-idp-llm\.sh"|__install_slm|g' | \
        # Replace script calls from main install.sh
        sed 's|"\${SCRIPT_DIR}/scripts/install-idp\.sh"|__install_idp|g' | \
        sed 's|"\${SCRIPT_DIR}/scripts/install-chat\.sh"|__install_chat|g' | \
        sed 's|"\${SCRIPT_DIR}/scripts/verify\.sh"|__verify_installation|g' | \
        # Replace REPO_DIR/models references with MODELS_CACHE_DIR
        sed 's|\${REPO_DIR}/models|\${MODELS_CACHE_DIR}|g' | \
        sed 's|\$REPO_DIR/models|\${MODELS_CACHE_DIR}|g' | \
        # Indent all lines
        sed 's/^/    /'

    echo "}"
}

# Process the main install.sh for the generated output
process_main_shell_script() {
    local script_path="$1"

    tail -n +2 "${script_path}" | \
        # Remove set -e
        sed '/^[[:space:]]*set[[:space:]]\{1,\}-e[[:space:]]*$/d' | \
        # Remove color definitions
        sed '/^[[:space:]]*RED=/d' | \
        sed '/^[[:space:]]*GREEN=/d' | \
        sed '/^[[:space:]]*YELLOW=/d' | \
        sed '/^[[:space:]]*BLUE=/d' | \
        sed '/^[[:space:]]*CYAN=/d' | \
        sed '/^[[:space:]]*NC=/d' | \
        # Remove SCRIPT_DIR
        sed '/^[[:space:]]*SCRIPT_DIR=/d' | \
        # Replace script calls
        sed 's|"\${SCRIPT_DIR}/scripts/install-idp\.sh"|__install_idp|g' | \
        sed 's|"\${SCRIPT_DIR}/scripts/install-chat\.sh"|__install_chat|g' | \
        sed 's|"\${SCRIPT_DIR}/scripts/verify\.sh"|__verify_installation|g'
}

build_shell() {
    echo "Building dist/install.sh..."
    mkdir -p "${DIST_DIR}"

    local output="${DIST_DIR}/install.sh"

    {
        # Header
        cat << 'HEADER'
#!/bin/bash
#
# Faria Installation Script - Single-file Installer
# AUTO-GENERATED FILE - DO NOT EDIT DIRECTLY
#
# Generated from modular source files by build/build.sh
# Source: https://github.com/exto360-inc/faria-install
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/exto360-inc/faria-install/main/dist/install.sh | bash -s -- --features idp
#   curl -fsSL https://raw.githubusercontent.com/exto360-inc/faria-install/main/dist/install.sh | bash -s -- --features chat
#   curl -fsSL https://raw.githubusercontent.com/exto360-inc/faria-install/main/dist/install.sh | bash -s -- --features all
#

set -e

HEADER
        echo "# Build date: ${BUILD_DATE}"
        echo "# GitHub URL: ${GITHUB_RAW_URL}"
        echo ""

        # Inline common library
        echo "# ============================================================================"
        echo "# Common Utilities (from scripts/_common.sh)"
        echo "# ============================================================================"
        echo ""
        # Skip the shebang and header comments from _common.sh
        tail -n +8 "${ROOT_DIR}/scripts/_common.sh"
        echo ""

        # Add GitHub download helper for models
        cat << 'MODELS_HELPER'

# ============================================================================
# Models Cache Helper (downloads Python scripts from GitHub)
# ============================================================================
MODELS_CACHE_DIR=""

__setup_models_cache() {
    if [ -n "${MODELS_CACHE_DIR}" ] && [ -d "${MODELS_CACHE_DIR}" ]; then
        return 0
    fi

    MODELS_CACHE_DIR=$(mktemp -d)
    mkdir -p "${MODELS_CACHE_DIR}"

    echo -e "${YELLOW}Downloading model export scripts from GitHub...${NC}"

    local base_url="https://raw.githubusercontent.com/exto360-inc/faria-install/main/models"

    download_file_silent "${base_url}/requirements-detr.txt" "${MODELS_CACHE_DIR}/requirements-detr.txt" || return 1
    download_file_silent "${base_url}/requirements-nemotron.txt" "${MODELS_CACHE_DIR}/requirements-nemotron.txt" || return 1
    download_file_silent "${base_url}/export_detr_layout_onnx.py" "${MODELS_CACHE_DIR}/export_detr_layout_onnx.py" || return 1
    download_file_silent "${base_url}/export_nemotron_onnx.py" "${MODELS_CACHE_DIR}/export_nemotron_onnx.py" || return 1

    echo -e "${GREEN}Model scripts downloaded.${NC}"
}

__cleanup_models_cache() {
    if [ -n "${MODELS_CACHE_DIR}" ] && [ -d "${MODELS_CACHE_DIR}" ]; then
        rm -rf "${MODELS_CACHE_DIR}"
        MODELS_CACHE_DIR=""
    fi
}

MODELS_HELPER

        # Convert component scripts to functions
        local scripts=(
            "${ROOT_DIR}/scripts/setup-python.sh:__setup_python"
            "${ROOT_DIR}/scripts/install-opencv.sh:__install_opencv"
            "${ROOT_DIR}/scripts/install-tesseract.sh:__install_tesseract"
            "${ROOT_DIR}/scripts/install-mupdf.sh:__install_mupdf"
            "${ROOT_DIR}/scripts/install-onnxruntime.sh:__install_onnxruntime"
            "${ROOT_DIR}/scripts/install-models.sh:__install_models"
            "${ROOT_DIR}/scripts/install-slm.sh:__install_slm"
            "${ROOT_DIR}/scripts/verify.sh:__verify_installation"
            "${ROOT_DIR}/scripts/install-idp.sh:__install_idp"
            "${ROOT_DIR}/scripts/install-chat.sh:__install_chat"
        )

        for entry in "${scripts[@]}"; do
            local script_path="${entry%%:*}"
            local func_name="${entry##*:}"
            convert_shell_script_to_function "${script_path}" "${func_name}"
        done

        echo ""
        echo "# ============================================================================"
        echo "# Main Orchestrator"
        echo "# ============================================================================"
        echo ""

        # Process main script
        process_main_shell_script "${ROOT_DIR}/install.sh"

        # Add cleanup trap at the end
        echo ""
        echo "# Cleanup models cache on exit"
        echo "trap __cleanup_models_cache EXIT"

    } > "${output}"

    chmod +x "${output}"

    local size=$(du -h "${output}" | cut -f1)
    local lines=$(wc -l < "${output}" | tr -d ' ')
    echo "  Created: ${output}"
    echo "  Size: ${size}, Lines: ${lines}"
}

# ============================================================================
# PowerShell Script Builder
# ============================================================================

convert_ps1_script_to_function() {
    local script_path="$1"
    local func_name="$2"

    if [ ! -f "${script_path}" ]; then
        echo "    Warning: Script not found: ${script_path}" >&2
        return
    fi

    echo ""
    echo "# ============================================================================"
    echo "# ${func_name} - from $(basename "${script_path}")"
    echo "# ============================================================================"
    echo "function ${func_name} {"
    echo "    param("
    echo "        [string]\$InstallDir = \"\$env:USERPROFILE\\.faria\","
    echo "        [switch]\$GPU,"
    echo "        [switch]\$WithLLM"
    echo "    )"
    echo ""

    # Process with sed - skip param block and transform
    # First, extract content after param block
    local in_content=false
    local paren_depth=0

    tail -n +1 "${script_path}" | while IFS= read -r line || [ -n "$line" ]; do
        # Skip leading comments
        if [ "$in_content" = false ] && [[ "$line" =~ ^[[:space:]]*# ]]; then
            continue
        fi

        # Track param block
        if [ "$in_content" = false ] && [[ "$line" =~ ^[[:space:]]*param\( ]]; then
            in_content="skipping_param"
            paren_depth=1
            continue
        fi

        if [ "$in_content" = "skipping_param" ]; then
            # Count parentheses
            local opens=$(echo "$line" | tr -cd '(' | wc -c | tr -d ' ')
            local closes=$(echo "$line" | tr -cd ')' | wc -c | tr -d ' ')
            paren_depth=$((paren_depth + opens - closes))
            if [ "$paren_depth" -le 0 ]; then
                in_content=true
            fi
            continue
        fi

        if [ "$in_content" = false ]; then
            in_content=true
        fi

        # Skip ScriptDir calculations
        [[ "$line" =~ ^\$ScriptDir ]] && continue

        # Transform script calls
        line=$(echo "$line" | sed 's|\$ScriptDir\\setup-toolchain\.ps1|Invoke-SetupToolchain|g')
        line=$(echo "$line" | sed 's|\$ScriptDir\\install-opencv\.ps1|Invoke-InstallOpenCV|g')
        line=$(echo "$line" | sed 's|\$ScriptDir\\install-tesseract\.ps1|Invoke-InstallTesseract|g')
        line=$(echo "$line" | sed 's|\$ScriptDir\\install-mupdf\.ps1|Invoke-InstallMuPDF|g')
        line=$(echo "$line" | sed 's|\$ScriptDir\\install-onnxruntime\.ps1|Invoke-InstallOnnxRuntime|g')
        line=$(echo "$line" | sed 's|\$ScriptDir\\install-models\.ps1|Invoke-InstallModels|g')
        line=$(echo "$line" | sed 's|\$ScriptDir\\install-slm\.ps1|Invoke-InstallSLM|g')
        line=$(echo "$line" | sed 's|\$ScriptDir\\scripts\\install-idp\.ps1|Invoke-InstallIDP|g')
        line=$(echo "$line" | sed 's|\$ScriptDir\\scripts\\install-chat\.ps1|Invoke-InstallChat|g')
        line=$(echo "$line" | sed 's|\$ScriptDir\\scripts\\verify\.ps1|Invoke-Verify|g')
        line=$(echo "$line" | sed 's|\$ScriptDir\\setup-python\.ps1|Initialize-Python|g')

        # Indent
        echo "    $line"
    done

    echo "}"
}

build_powershell() {
    echo "Building dist/install.ps1..."
    mkdir -p "${DIST_DIR}"

    local output="${DIST_DIR}/install.ps1"

    {
        # Header
        cat << 'HEADER'
#
# Faria Installation Script - Single-file Installer for Windows
# AUTO-GENERATED FILE - DO NOT EDIT DIRECTLY
#
# Generated from modular source files by build/build.sh
# Source: https://github.com/exto360-inc/faria-install
#
# Usage:
#   irm https://raw.githubusercontent.com/exto360-inc/faria-install/main/dist/install.ps1 | iex
#
# Or download and run:
#   Invoke-WebRequest -Uri "..." -OutFile "install.ps1"
#   .\install.ps1 -Features idp
#   .\install.ps1 -Features chat
#   .\install.ps1 -Features all
#

HEADER
        echo "# Build date: ${BUILD_DATE}"
        echo "# GitHub URL: ${GITHUB_RAW_URL}"
        echo ""

        # Main param block
        cat << 'PARAMS'
param(
    [string]$Features = "",
    [string]$InstallDir = "$env:USERPROFILE\.faria",
    [switch]$GPU,
    [switch]$WithLLM,
    [switch]$System,
    [switch]$Help
)

PARAMS

        # Inline common library
        echo "# ============================================================================"
        echo "# Common Utilities (from scripts/_common.ps1)"
        echo "# ============================================================================"
        echo ""
        # Skip the header comments
        tail -n +7 "${ROOT_DIR}/scripts/_common.ps1"
        echo ""

        # Add models cache helper
        cat << 'PS_MODELS_HELPER'

# ============================================================================
# Models Cache Helper
# ============================================================================
$script:ModelsCacheDir = $null

function Initialize-ModelsCache {
    if ($script:ModelsCacheDir -and (Test-Path $script:ModelsCacheDir)) {
        return $script:ModelsCacheDir
    }

    $script:ModelsCacheDir = New-TempDirectory -Prefix "faria-models"

    Write-Host "Downloading model export scripts from GitHub..." -ForegroundColor Yellow

    $baseUrl = "https://raw.githubusercontent.com/exto360-inc/faria-install/main/models"

    $files = @(
        "requirements-detr.txt",
        "requirements-nemotron.txt",
        "export_detr_layout_onnx.py",
        "export_nemotron_onnx.py"
    )

    foreach ($file in $files) {
        $dest = Join-Path $script:ModelsCacheDir $file
        if (-not (Invoke-Download -Url "$baseUrl/$file" -Destination $dest -Silent)) {
            Write-Host "Failed to download: $file" -ForegroundColor Red
            return $null
        }
    }

    Write-Host "Model scripts downloaded." -ForegroundColor Green
    return $script:ModelsCacheDir
}

function Remove-ModelsCache {
    if ($script:ModelsCacheDir -and (Test-Path $script:ModelsCacheDir)) {
        Remove-TempDirectory -Path $script:ModelsCacheDir
        $script:ModelsCacheDir = $null
    }
}

PS_MODELS_HELPER

        # Convert component scripts to functions
        local scripts=(
            "${ROOT_DIR}/scripts/setup-python.ps1:Initialize-Python"
            "${ROOT_DIR}/scripts/setup-toolchain.ps1:Invoke-SetupToolchain"
            "${ROOT_DIR}/scripts/install-opencv.ps1:Invoke-InstallOpenCV"
            "${ROOT_DIR}/scripts/install-tesseract.ps1:Invoke-InstallTesseract"
            "${ROOT_DIR}/scripts/install-mupdf.ps1:Invoke-InstallMuPDF"
            "${ROOT_DIR}/scripts/install-onnxruntime.ps1:Invoke-InstallOnnxRuntime"
            "${ROOT_DIR}/scripts/install-models.ps1:Invoke-InstallModels"
            "${ROOT_DIR}/scripts/install-slm.ps1:Invoke-InstallSLM"
            "${ROOT_DIR}/scripts/verify.ps1:Invoke-Verify"
            "${ROOT_DIR}/scripts/install-idp.ps1:Invoke-InstallIDP"
            "${ROOT_DIR}/scripts/install-chat.ps1:Invoke-InstallChat"
        )

        for entry in "${scripts[@]}"; do
            local script_path="${entry%%:*}"
            local func_name="${entry##*:}"
            convert_ps1_script_to_function "${script_path}" "${func_name}"
        done

        echo ""
        echo "# ============================================================================"
        echo "# Main Orchestrator"
        echo "# ============================================================================"
        echo ""

        # Include main orchestrator logic
        cat << 'MAIN_PS1'

# Handle help
if ($Help) {
    Write-Host "Faria Installation Script"
    Write-Host ""
    Write-Host "Usage: irm <url> | iex  # or  .\install.ps1 [OPTIONS]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -Features LIST    Comma-separated list: idp, chat, all"
    Write-Host "  -InstallDir DIR   Install to DIR (default: $env:USERPROFILE\.faria)"
    Write-Host "  -GPU              Enable GPU support (CUDA)"
    Write-Host "  -WithLLM          Install LLM support for IDP"
    Write-Host "  -System           Download pre-exported ONNX models (skip Python)"
    Write-Host "  -Help             Show this help message"
    exit 0
}

# Banner
Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "               FARIA AI TOOLKIT                 " -ForegroundColor Blue
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

$Arch = Get-SystemArchitecture
Write-Host "System detected: Windows ($Arch)" -ForegroundColor Yellow
Write-Host "Install directory: $InstallDir" -ForegroundColor Yellow
Write-Host ""

# Feature selection
Write-Host "Available features:" -ForegroundColor Blue
Write-Host ""
Write-Host "  idp  - Intelligent Document Processing (~630 MB)" -ForegroundColor Green
Write-Host "         OpenCV, Tesseract, Leptonica, MuPDF, ONNX Runtime,"
Write-Host "         DETR model (layout detection), Nemotron model (tables), CLIP model"
Write-Host ""
Write-Host "  chat - Conversational AI (~535 MB)" -ForegroundColor Green
Write-Host "         llama.cpp, Qwen 2.5 model"
Write-Host ""

# Prompt for features if not specified
if ([string]::IsNullOrEmpty($Features)) {
    if (Test-Interactive) {
        Write-Host "Which features do you want to install?" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  1) idp only      - Document processing"
        Write-Host "  2) chat only     - Conversational AI"
        Write-Host "  3) idp + chat    - Both features"
        Write-Host "  4) Cancel"
        Write-Host ""
        $choice = Read-Host "Enter choice [1-4]"
        switch ($choice) {
            "1" { $Features = "idp" }
            "2" { $Features = "chat" }
            "3" { $Features = "idp,chat" }
            default {
                Write-Host "Installation cancelled."
                exit 0
            }
        }
    } else {
        Write-Host "Error: -Features parameter required in non-interactive mode" -ForegroundColor Red
        exit 1
    }
}

# Normalize "all"
if ($Features -eq "all") {
    $Features = "idp,chat"
}

# Parse features
$InstallIDP = $Features -match "idp"
$InstallChat = $Features -match "chat"

if (-not $InstallIDP -and -not $InstallChat) {
    Write-Host "Error: No valid features selected" -ForegroundColor Red
    exit 1
}

# Ask about LLM for IDP
$InstallIDPLLM = $false
if ($InstallIDP -and -not $WithLLM) {
    if (Test-Interactive) {
        Write-Host ""
        Write-Host "Would you like to install LLM support for IDP?" -ForegroundColor Yellow
        Write-Host "  This enables advanced document understanding capabilities."
        Write-Host "  (Requires additional ~500 MB disk space)"
        Write-Host ""
        if (Confirm-Action -Prompt "Install LLM for IDP? (y/N)") {
            $InstallIDPLLM = $true
        }
    }
} elseif ($WithLLM) {
    $InstallIDPLLM = $true
}

# Summary
Write-Host ""
Write-Host "Installation summary:" -ForegroundColor Blue
Write-Host "  - IDP (Document Processing): $(if ($InstallIDP) { 'yes' } else { 'no' })"
if ($InstallIDP) {
    Write-Host "    - LLM support: $(if ($InstallIDPLLM) { 'yes' } else { 'no' })"
    Write-Host "    - Model source: $(if ($System) { 'HuggingFace download (-System)' } else { 'local Python export' })"
}
Write-Host "  - Chat (Conversational AI): $(if ($InstallChat) { 'yes' } else { 'no' })"
Write-Host "  - GPU support: $(if ($GPU) { 'yes' } else { 'no' })"
Write-Host ""

if (Test-Interactive) {
    if (-not (Confirm-Action -Prompt "Continue with installation? (Y/n)" -Default "y")) {
        Write-Host "Installation cancelled."
        exit 0
    }
}

Write-Host ""

# Create install directory
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null

# Install IDP
if ($InstallIDP) {
    Write-Step -Step 1 -Total 3 -Name "Installing IDP Feature"

    try {
        Invoke-InstallIDP -InstallDir $InstallDir -GPU:$GPU -WithLLM:$InstallIDPLLM -System:$System
        Write-Host "IDP Feature installed successfully" -ForegroundColor Green
    } catch {
        Write-Host "IDP Feature installation failed: $_" -ForegroundColor Red
    }
    Write-Host ""
}

# Install Chat
if ($InstallChat) {
    Write-Step -Step 2 -Total 3 -Name "Installing Chat Feature"

    try {
        Invoke-InstallChat -InstallDir $InstallDir
        Write-Host "Chat Feature installed successfully" -ForegroundColor Green
    } catch {
        Write-Host "Chat Feature installation failed: $_" -ForegroundColor Red
    }
    Write-Host ""
}

# Verify
Write-Step -Step 3 -Total 3 -Name "Verifying Installation"

Invoke-Verify -InstallDir $InstallDir

# Cleanup
Remove-ModelsCache

# Final message
Write-SuccessBanner -Text "Installation Complete!"

Write-Host "Installed features:" -ForegroundColor Yellow
if ($InstallIDP) {
    Write-Host "  - IDP - OpenCV, Tesseract, MuPDF, ONNX Runtime, DETR, Nemotron, CLIP"
}
if ($InstallChat) {
    Write-Host "  - Chat - llama.cpp, Qwen 2.5"
}
Write-Host ""
Write-Host "Open a new PowerShell session for PATH and env var changes to take effect." -ForegroundColor Yellow
Write-Host ""
Write-Host "For more information, see: https://github.com/exto360-inc/faria"
Write-Host ""
MAIN_PS1

    } > "${output}"

    local size=$(du -h "${output}" | cut -f1)
    local lines=$(wc -l < "${output}" | tr -d ' ')
    echo "  Created: ${output}"
    echo "  Size: ${size}, Lines: ${lines}"
}

# ============================================================================
# Main
# ============================================================================

echo "Faria Installer Build System"
echo "============================"
echo ""
echo "Root directory: ${ROOT_DIR}"
echo "Output directory: ${DIST_DIR}"
echo ""

case "${1:-all}" in
    --sh-only)
        build_shell
        ;;
    --ps1-only)
        build_powershell
        ;;
    --help|-h)
        echo "Usage: $0 [--sh-only | --ps1-only | --help]"
        echo ""
        echo "Options:"
        echo "  --sh-only   Build only shell installer (dist/install.sh)"
        echo "  --ps1-only  Build only PowerShell installer (dist/install.ps1)"
        echo "  --help      Show this help message"
        echo ""
        echo "Without options, builds both installers."
        exit 0
        ;;
    *)
        build_shell
        echo ""
        build_powershell
        ;;
esac

echo ""
echo "Build complete!"
echo ""
echo "Test the installers:"
echo "  ./dist/install.sh --help"
echo "  cat dist/install.sh | bash -s -- --help"
echo ""
