#
# Faria IDP (Intelligent Document Processing) Installation Script
# Orchestrates installation of all IDP dependencies:
#   - OpenCV (image processing)
#   - Tesseract + Leptonica (OCR)
#   - MuPDF (PDF processing)
#   - ONNX Runtime (model inference)
#   - DETR + Nemotron models (layout detection, table extraction)
#
# Usage: .\install-idp.ps1 [OPTIONS]
#

param(
    [string]$InstallDir = "$env:USERPROFILE\.faria",
    [switch]$GPU,
    [switch]$WithLLM,
    [switch]$Help
)

if ($Help) {
    Write-Host "Faria IDP Installation Script"
    Write-Host ""
    Write-Host "Usage: .\install-idp.ps1 [OPTIONS]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -InstallDir DIR  Install to DIR (default: $env:USERPROFILE\.faria)"
    Write-Host "  -GPU             Enable GPU support (CUDA)"
    Write-Host "  -WithLLM         Install LLM support for advanced document understanding"
    Write-Host "  -Help            Show this help message"
    Write-Host ""
    Write-Host "This script installs all dependencies for IDP (Intelligent Document Processing):"
    Write-Host "  - OpenCV           Image processing"
    Write-Host "  - Tesseract        OCR engine"
    Write-Host "  - Leptonica        Image library (with Tesseract)"
    Write-Host "  - MuPDF            PDF processing"
    Write-Host "  - ONNX Runtime     Model inference"
    Write-Host "  - DETR model       Layout detection"
    Write-Host "  - Nemotron model   Table extraction"
    exit 0
}

# Get script directory
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "   Faria IDP Dependencies Installation" -ForegroundColor Blue
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Install directory: $InstallDir" -ForegroundColor Yellow
Write-Host ""

# Track installation status
$script:InstallFailed = $false
$TotalSteps = 5
if ($WithLLM) { $TotalSteps++ }
$script:CurrentStep = 0

# Helper function to run a step
function Invoke-Step {
    param(
        [string]$StepName,
        [string]$Script,
        [hashtable]$Arguments = @{}
    )

    $script:CurrentStep++
    Write-Host ""
    Write-Host "-----------------------------------------------------------------" -ForegroundColor Blue
    Write-Host "  Step $($script:CurrentStep)/$TotalSteps`: $StepName" -ForegroundColor Blue
    Write-Host "-----------------------------------------------------------------" -ForegroundColor Blue
    Write-Host ""

    try {
        if ($Arguments.Count -gt 0) {
            & "$ScriptDir\$Script" @Arguments
        } else {
            & "$ScriptDir\$Script"
        }
        if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) {
            throw "Script returned exit code $LASTEXITCODE"
        }
        Write-Host "[OK] $StepName completed successfully" -ForegroundColor Green
    } catch {
        Write-Host "[X] $StepName failed: $_" -ForegroundColor Red
        $script:InstallFailed = $true
    }
}

# Create install directory
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null

# Step 1: Install OpenCV
Invoke-Step -StepName "Installing OpenCV" -Script "install-opencv.ps1" -Arguments @{InstallDir = $InstallDir}

# Step 2: Install Tesseract (includes Leptonica)
Invoke-Step -StepName "Installing Tesseract OCR" -Script "install-tesseract.ps1"

# Step 3: Install MuPDF
Invoke-Step -StepName "Installing MuPDF" -Script "install-mupdf.ps1" -Arguments @{InstallDir = $InstallDir}

# Step 4: Install ONNX Runtime
$OnnxArgs = @{InstallDir = $InstallDir}
if ($GPU) { $OnnxArgs.GPU = $true }
Invoke-Step -StepName "Installing ONNX Runtime" -Script "install-onnxruntime.ps1" -Arguments $OnnxArgs

# Step 5: Install ML Models (DETR + Nemotron)
Invoke-Step -StepName "Installing ML Models" -Script "install-models.ps1" -Arguments @{InstallDir = $InstallDir}

# Step 6 (optional): Install LLM for IDP
if ($WithLLM) {
    Invoke-Step -StepName "Installing LLM for IDP" -Script "install-slm.ps1" -Arguments @{InstallDir = $InstallDir}
}

# Final Summary
Write-Host ""
Write-Host "=================================================================" -ForegroundColor Cyan
if (-not $script:InstallFailed) {
    Write-Host "   IDP Dependencies Installed Successfully!" -ForegroundColor Green
} else {
    Write-Host "   IDP Installation Completed with Warnings" -ForegroundColor Yellow
}
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Installed components:" -ForegroundColor Yellow
Write-Host "  - OpenCV       - Image processing"
Write-Host "  - Tesseract    - OCR engine"
Write-Host "  - Leptonica    - Image library"
Write-Host "  - MuPDF        - PDF processing"
Write-Host "  - ONNX Runtime - Model inference"
Write-Host "  - DETR model   - Layout detection"
Write-Host "  - Nemotron     - Table extraction"
if ($WithLLM) {
    Write-Host "  - LLM          - Advanced document understanding"
}
Write-Host ""

if ($script:InstallFailed) {
    exit 1
}
