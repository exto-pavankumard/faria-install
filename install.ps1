#
# Faria Installation Script for Windows
# Main orchestration script for installing Faria dependencies
#
# Usage: .\install.ps1 [OPTIONS]
#
# Features:
#   idp  - Intelligent Document Processing (OpenCV, Tesseract, MuPDF, ONNX, models)
#   chat - Conversational AI (llama.cpp, Qwen model)
#
# Examples:
#   .\install.ps1 -Features idp          # Install IDP only
#   .\install.ps1 -Features chat         # Install Chat only
#   .\install.ps1 -Features "idp,chat"   # Install both
#   .\install.ps1 -Features all          # Install everything
#   .\install.ps1                        # Interactive mode
#

param(
    [string]$InstallDir = "$env:USERPROFILE\.faria",
    [string]$Features = "",
    [switch]$GPU,
    [switch]$WithLLM,
    [switch]$Help
)

if ($Help) {
    Write-Host "Faria Installation Script"
    Write-Host ""
    Write-Host "Usage: .\install.ps1 [OPTIONS]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -Features LIST     Comma-separated list of features to install"
    Write-Host "                     Available: idp, chat, all"
    Write-Host "  -InstallDir DIR    Install to DIR (default: $env:USERPROFILE\.faria)"
    Write-Host "  -GPU               Enable GPU support (CUDA)"
    Write-Host "  -WithLLM           Install LLM support for IDP (advanced document understanding)"
    Write-Host "  -Help              Show this help message"
    Write-Host ""
    Write-Host "Features:"
    Write-Host "  idp   - Intelligent Document Processing (~630 MB)"
    Write-Host "          OpenCV, Tesseract, Leptonica, MuPDF, ONNX Runtime,"
    Write-Host "          DETR model, Nemotron model"
    Write-Host "          Optional: LLM support (~500 MB extra, use -WithLLM)"
    Write-Host ""
    Write-Host "  chat  - Conversational AI (~535 MB)"
    Write-Host "          llama.cpp, Qwen 2.5 model"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\install.ps1 -Features idp            # IDP only"
    Write-Host "  .\install.ps1 -Features chat           # Chat only"
    Write-Host "  .\install.ps1 -Features `"idp,chat`"     # Both features"
    Write-Host "  .\install.ps1 -Features all            # Everything"
    Write-Host "  .\install.ps1                          # Interactive mode"
    exit 0
}

# Get script directory
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Banner
Write-Host ""
Write-Host "===============================================================" -ForegroundColor Cyan
Write-Host "                                                               " -ForegroundColor Cyan
Write-Host "   FARIA - AI Toolkit                                          " -ForegroundColor Blue
Write-Host "                                                               " -ForegroundColor Cyan
Write-Host "===============================================================" -ForegroundColor Cyan
Write-Host ""

# System info
$Arch = [System.Environment]::GetEnvironmentVariable("PROCESSOR_ARCHITECTURE")

Write-Host "System detected: Windows ($Arch)" -ForegroundColor Yellow
Write-Host "Install directory: $InstallDir" -ForegroundColor Yellow
Write-Host ""

# Show available features
Write-Host "Available features:" -ForegroundColor Blue
Write-Host ""
Write-Host "  idp  - Intelligent Document Processing (~630 MB)" -ForegroundColor Green
Write-Host "         OpenCV, Tesseract, Leptonica, MuPDF, ONNX Runtime,"
Write-Host "         DETR model (layout detection), Nemotron model (tables)"
Write-Host ""
Write-Host "  chat - Conversational AI (~535 MB)" -ForegroundColor Green
Write-Host "         llama.cpp, Qwen 2.5 model"
Write-Host ""

# Prompt for features if not specified
if ([string]::IsNullOrWhiteSpace($Features)) {
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
}

# Normalize "all" to actual features
if ($Features -eq "all") {
    $Features = "idp,chat"
}

# Parse features into flags
$InstallIDP = $false
$InstallChat = $false

$FeatureArray = $Features -split ','
foreach ($feature in $FeatureArray) {
    $feature = $feature.Trim()
    switch ($feature) {
        "idp" { $InstallIDP = $true }
        "chat" { $InstallChat = $true }
        default {
            if ($feature) {
                Write-Host "Warning: Unknown feature '$feature' ignored" -ForegroundColor Yellow
            }
        }
    }
}

# Validate at least one feature selected
if (-not $InstallIDP -and -not $InstallChat) {
    Write-Host "Error: No valid features selected" -ForegroundColor Red
    exit 1
}

# Ask about LLM for IDP if IDP is selected and -WithLLM not specified
$InstallIDPLLM = $WithLLM
if ($InstallIDP -and -not $WithLLM) {
    Write-Host ""
    Write-Host "Would you like to install LLM support for IDP?" -ForegroundColor Yellow
    Write-Host "  This enables advanced document understanding capabilities."
    Write-Host "  (Requires additional ~500 MB disk space)"
    Write-Host ""
    $response = Read-Host "Install LLM for IDP? (y/N)"
    if ($response -eq 'y' -or $response -eq 'Y') {
        $InstallIDPLLM = $true
    }
}

Write-Host ""
Write-Host "Installation summary:" -ForegroundColor Blue
Write-Host "  - IDP (Document Processing): $(if ($InstallIDP) { 'yes' } else { 'no' })"
if ($InstallIDP) {
    Write-Host "    - LLM support: $(if ($InstallIDPLLM) { 'yes' } else { 'no' })"
}
Write-Host "  - Chat (Conversational AI): $(if ($InstallChat) { 'yes' } else { 'no' })"
Write-Host "  - GPU support: $(if ($GPU) { 'yes' } else { 'no' })"
Write-Host ""

$response = Read-Host "Continue with installation? (Y/n)"
if ($response -eq 'n' -or $response -eq 'N') {
    Write-Host "Installation cancelled."
    exit 0
}

Write-Host ""

# Create install directory
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null

# Track installation status
$InstallFailed = $false
$TotalSteps = 0
$CurrentStep = 0

# Calculate total steps
if ($InstallIDP) { $TotalSteps++ }
if ($InstallChat) { $TotalSteps++ }
$TotalSteps++  # Verification

# ============================================================================
# Install IDP Feature
# ============================================================================
if ($InstallIDP) {
    $CurrentStep++
    Write-Host "=================================================================" -ForegroundColor Blue
    Write-Host "  Step $CurrentStep/$TotalSteps`: Installing IDP Feature" -ForegroundColor Blue
    Write-Host "=================================================================" -ForegroundColor Blue
    Write-Host ""

    $IDPArgs = @{InstallDir = $InstallDir}
    if ($GPU) { $IDPArgs.GPU = $true }
    if ($InstallIDPLLM) { $IDPArgs.WithLLM = $true }

    try {
        & "$ScriptDir\scripts\install-idp.ps1" @IDPArgs
        if ($LASTEXITCODE -ne 0) { throw "IDP installation returned exit code $LASTEXITCODE" }
        Write-Host "[OK] IDP Feature installed successfully" -ForegroundColor Green
    } catch {
        Write-Host "[X] IDP Feature installation failed: $_" -ForegroundColor Red
        $InstallFailed = $true
    }

    Write-Host ""
}

# ============================================================================
# Install Chat Feature
# ============================================================================
if ($InstallChat) {
    $CurrentStep++
    Write-Host "=================================================================" -ForegroundColor Blue
    Write-Host "  Step $CurrentStep/$TotalSteps`: Installing Chat Feature" -ForegroundColor Blue
    Write-Host "=================================================================" -ForegroundColor Blue
    Write-Host ""

    try {
        & "$ScriptDir\scripts\install-chat.ps1" -InstallDir $InstallDir
        if ($LASTEXITCODE -ne 0) { throw "Chat installation returned exit code $LASTEXITCODE" }
        Write-Host "[OK] Chat Feature installed successfully" -ForegroundColor Green
    } catch {
        Write-Host "[X] Chat Feature installation failed: $_" -ForegroundColor Red
        $InstallFailed = $true
    }

    Write-Host ""
}

# ============================================================================
# Verify Installation
# ============================================================================
$CurrentStep++
Write-Host "=================================================================" -ForegroundColor Blue
Write-Host "  Step $CurrentStep/$TotalSteps`: Verifying Installation" -ForegroundColor Blue
Write-Host "=================================================================" -ForegroundColor Blue
Write-Host ""

& "$ScriptDir\scripts\verify.ps1" -InstallDir $InstallDir

# ============================================================================
# Final Summary
# ============================================================================
Write-Host ""
Write-Host "===============================================================" -ForegroundColor Cyan
if (-not $InstallFailed) {
    Write-Host "                                                               " -ForegroundColor Cyan
    Write-Host "   Installation Complete!                                      " -ForegroundColor Green
    Write-Host "                                                               " -ForegroundColor Cyan
} else {
    Write-Host "                                                               " -ForegroundColor Cyan
    Write-Host "   Installation completed with warnings                        " -ForegroundColor Yellow
    Write-Host "                                                               " -ForegroundColor Cyan
}
Write-Host "===============================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Installed features:" -ForegroundColor Yellow
if ($InstallIDP) {
    Write-Host "  - IDP - OpenCV, Tesseract, MuPDF, ONNX Runtime, DETR, Nemotron"
}
if ($InstallChat) {
    Write-Host "  - Chat - llama.cpp, Qwen 2.5"
}
Write-Host ""

Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. Add environment variables to your profile (optional):"
Write-Host "   See the output above for the exact paths."
Write-Host ""
Write-Host "2. Or use auto-detection (no configuration needed):"
Write-Host "   Faria will automatically find files in $env:USERPROFILE\.faria\"
Write-Host ""
Write-Host "3. Start using Faria in your Go code:"
Write-Host ""
Write-Host "   config := faria.DefaultConfig()" -ForegroundColor Blue
Write-Host "   client, err := faria.New(config)" -ForegroundColor Blue
Write-Host ""
Write-Host "For more information, see: https://github.com/exto360-inc/faria"
Write-Host ""
