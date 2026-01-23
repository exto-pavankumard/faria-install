#
# Faria Installation Script for Windows
# Main orchestration script for installing all Faria dependencies
#
# Usage: .\install.ps1 [OPTIONS]
#
# This script installs:
#   Required:
#     - ONNX Runtime (inference engine)
#     - DETR model (layout detection)
#     - Nemotron model (table structure)
#     - Tesseract OCR (text extraction)
#   Optional:
#     - llama.cpp + Qwen model (cross-page table merging)
#

param(
    [string]$InstallDir = "$env:USERPROFILE\.faria",
    [switch]$GPU,
    [switch]$WithLLM,
    [switch]$NoLLM,
    [switch]$SkipTesseract,
    [switch]$Help
)

if ($Help) {
    Write-Host "Faria Installation Script"
    Write-Host ""
    Write-Host "Usage: .\install.ps1 [OPTIONS]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -InstallDir DIR   Install to DIR (default: $env:USERPROFILE\.faria)"
    Write-Host "  -GPU              Enable GPU support (CUDA)"
    Write-Host "  -WithLLM          Install LLM components without prompting"
    Write-Host "  -NoLLM            Skip LLM components without prompting"
    Write-Host "  -SkipTesseract    Skip Tesseract if already installed"
    Write-Host "  -Help             Show this help message"
    Write-Host ""
    Write-Host "Components:"
    Write-Host "  Required:"
    Write-Host "    - ONNX Runtime    Model inference engine (~50 MB)"
    Write-Host "    - DETR            Layout detection model (~350 MB)"
    Write-Host "    - Nemotron        Table structure model (~200 MB)"
    Write-Host "    - Tesseract OCR   Text extraction (~30 MB)"
    Write-Host ""
    Write-Host "  Optional (LLM for cross-page table merging):"
    Write-Host "    - llama.cpp       LLM inference engine (~5 MB)"
    Write-Host "    - Qwen 2.5        Language model (~530 MB)"
    exit 0
}

# Get script directory
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Banner
Write-Host ""
Write-Host "===============================================================" -ForegroundColor Cyan
Write-Host "                                                               " -ForegroundColor Cyan
Write-Host "   FARIA - Intelligent Document Processing                     " -ForegroundColor Blue
Write-Host "                                                               " -ForegroundColor Cyan
Write-Host "===============================================================" -ForegroundColor Cyan
Write-Host ""

# System info
$Arch = [System.Environment]::GetEnvironmentVariable("PROCESSOR_ARCHITECTURE")

Write-Host "System detected: Windows ($Arch)" -ForegroundColor Yellow
Write-Host "Install directory: $InstallDir" -ForegroundColor Yellow
Write-Host ""

# Show what will be installed
Write-Host "This script will install:" -ForegroundColor Blue
Write-Host ""
Write-Host "  Required components:" -ForegroundColor Green
Write-Host "    - ONNX Runtime    - Model inference engine"
Write-Host "    - DETR model      - Document layout detection"
Write-Host "    - Nemotron model  - Table structure detection"
if (-not $SkipTesseract) {
    Write-Host "    - Tesseract OCR   - Text extraction"
} else {
    Write-Host "    - Tesseract OCR   - (skipped)" -ForegroundColor Yellow
}
Write-Host ""
Write-Host "  Optional components:" -ForegroundColor Yellow
Write-Host "    - LLM (llama.cpp + Qwen) - Cross-page table merging"
Write-Host ""

# Determine LLM installation
$InstallLLM = $null
if ($WithLLM) {
    $InstallLLM = $true
} elseif ($NoLLM) {
    $InstallLLM = $false
} else {
    Write-Host "The LLM component enables intelligent cross-page table merging." -ForegroundColor Yellow
    Write-Host "It requires ~535 MB of additional disk space."
    Write-Host ""
    $response = Read-Host "Do you want to install LLM components? (y/N)"
    $InstallLLM = ($response -eq 'y' -or $response -eq 'Y')
}

Write-Host ""
Write-Host "Installation summary:" -ForegroundColor Blue
Write-Host "  - ONNX Runtime: yes"
Write-Host "  - DETR model: yes"
Write-Host "  - Nemotron model: yes"
Write-Host "  - Tesseract OCR: $(if ($SkipTesseract) { 'skip' } else { 'yes' })"
Write-Host "  - LLM components: $(if ($InstallLLM) { 'yes' } else { 'no' })"
Write-Host "  - GPU support: $(if ($GPU) { 'yes' } else { 'no' })"
Write-Host "  - DirectML: yes"
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
$TotalSteps = 4
if ($InstallLLM) { $TotalSteps = 5 }
if ($SkipTesseract) { $TotalSteps-- }

$CurrentStep = 0

# ============================================================================
# Step 1: Install ONNX Runtime
# ============================================================================
$CurrentStep++
Write-Host "=================================================================" -ForegroundColor Blue
Write-Host "  Step $CurrentStep/$TotalSteps`: Installing ONNX Runtime" -ForegroundColor Blue
Write-Host "=================================================================" -ForegroundColor Blue
Write-Host ""

$OnnxArgs = @("-InstallDir", $InstallDir)
if ($GPU) { $OnnxArgs += "-GPU" }

try {
    & "$ScriptDir\scripts\install-onnxruntime.ps1" @OnnxArgs
    Write-Host "[OK] ONNX Runtime installed successfully" -ForegroundColor Green
} catch {
    Write-Host "[X] ONNX Runtime installation failed: $_" -ForegroundColor Red
    $InstallFailed = $true
}

Write-Host ""

# ============================================================================
# Step 2: Install Tesseract OCR
# ============================================================================
if (-not $SkipTesseract) {
    $CurrentStep++
    Write-Host "=================================================================" -ForegroundColor Blue
    Write-Host "  Step $CurrentStep/$TotalSteps`: Installing Tesseract OCR" -ForegroundColor Blue
    Write-Host "=================================================================" -ForegroundColor Blue
    Write-Host ""

    try {
        & "$ScriptDir\scripts\install-tesseract.ps1"
        Write-Host "[OK] Tesseract OCR installed successfully" -ForegroundColor Green
    } catch {
        Write-Host "[X] Tesseract OCR installation failed: $_" -ForegroundColor Red
        $InstallFailed = $true
    }

    Write-Host ""
}

# ============================================================================
# Step 3: Install ML Models (DETR + Nemotron)
# ============================================================================
$CurrentStep++
Write-Host "=================================================================" -ForegroundColor Blue
Write-Host "  Step $CurrentStep/$TotalSteps`: Installing ML Models (DETR + Nemotron)" -ForegroundColor Blue
Write-Host "=================================================================" -ForegroundColor Blue
Write-Host ""

try {
    & "$ScriptDir\scripts\install-models.ps1" -InstallDir $InstallDir
    Write-Host "[OK] ML Models installed successfully" -ForegroundColor Green
} catch {
    Write-Host "[X] ML Models installation failed: $_" -ForegroundColor Red
    $InstallFailed = $true
}

Write-Host ""

# ============================================================================
# Step 4: Install LLM (Optional)
# ============================================================================
if ($InstallLLM) {
    $CurrentStep++
    Write-Host "=================================================================" -ForegroundColor Blue
    Write-Host "  Step $CurrentStep/$TotalSteps`: Installing LLM Components" -ForegroundColor Blue
    Write-Host "=================================================================" -ForegroundColor Blue
    Write-Host ""

    try {
        & "$ScriptDir\scripts\install-slm.ps1" -InstallDir $InstallDir
        Write-Host "[OK] LLM Components installed successfully" -ForegroundColor Green
    } catch {
        Write-Host "[X] LLM Components installation failed: $_" -ForegroundColor Red
        Write-Host "Note: LLM is optional, continuing with installation..." -ForegroundColor Yellow
    }

    Write-Host ""
}

# ============================================================================
# Step 5: Verify Installation
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
