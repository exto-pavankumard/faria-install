#
# Faria IDP (Intelligent Document Processing) Installation Script
# Orchestrates installation of all IDP dependencies:
#   - MinGW-w64 toolchain (for CGO compilation)
#   - OpenCV (image processing)
#   - Tesseract + Leptonica (OCR)
#   - MuPDF (PDF processing)
#   - ONNX Runtime (model inference)
#   - DETR + Nemotron + CLIP models
#
# Usage: .\install-idp.ps1 [OPTIONS]
#

param(
    [string]$InstallDir = "$env:USERPROFILE\.faria",
    [switch]$GPU,
    [switch]$WithLLM,
    [switch]$System,
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
    Write-Host "  -System          Download pre-exported ONNX models from HuggingFace (skip Python)"
    Write-Host "  -Help            Show this help message"
    exit 0
}

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

if (-not (Get-Command 'Set-UserEnv' -ErrorAction SilentlyContinue)) {
    . (Join-Path $PSScriptRoot '_common.ps1')
}

Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "   Faria IDP Dependencies Installation" -ForegroundColor Blue
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Install directory: $InstallDir" -ForegroundColor Yellow
Write-Host ""

$script:InstallFailed = $false
$TotalSteps = 6  # toolchain + opencv + tesseract + mupdf + onnx + models
if ($WithLLM) { $TotalSteps++ }
$script:CurrentStep = 0

# Step runner: increments counter, prints header, executes scriptblock, catches failures.
# Uses a scriptblock so the build system can transform the direct $ScriptDir\*.ps1 calls
# inside each block into the corresponding inlined Invoke-* function calls.
function Invoke-IDPStep {
    param([string]$Name, [scriptblock]$Action)
    $script:CurrentStep++
    Write-Host ""
    Write-Host "-----------------------------------------------------------------" -ForegroundColor Blue
    Write-Host "  Step $($script:CurrentStep)/$TotalSteps`: $Name" -ForegroundColor Blue
    Write-Host "-----------------------------------------------------------------" -ForegroundColor Blue
    Write-Host ""
    try {
        $global:LASTEXITCODE = 0  # prevent stale exit codes from previous steps leaking in
        & $Action
        Write-Host "[OK] $Name completed successfully" -ForegroundColor Green
    } catch {
        Write-Host "[X] $Name failed: $_" -ForegroundColor Red
        $script:InstallFailed = $true
    }
}

New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null

# Step 0: Toolchain (MSYS2 + MinGW-w64 + pkg-config) — must come first
Invoke-IDPStep -Name "Setting up MinGW-w64 toolchain" -Action {
    & "$ScriptDir\setup-toolchain.ps1" -InstallDir $InstallDir
    if ($LASTEXITCODE -ne 0 -and $null -ne $LASTEXITCODE) { throw "exit code $LASTEXITCODE" }
}

# Step 1: OpenCV
Invoke-IDPStep -Name "Installing OpenCV" -Action {
    & "$ScriptDir\install-opencv.ps1" -InstallDir $InstallDir
    if ($LASTEXITCODE -ne 0 -and $null -ne $LASTEXITCODE) { throw "exit code $LASTEXITCODE" }
}

# Step 2: Tesseract (includes Leptonica)
Invoke-IDPStep -Name "Installing Tesseract OCR" -Action {
    & "$ScriptDir\install-tesseract.ps1" -InstallDir $InstallDir
    if ($LASTEXITCODE -ne 0 -and $null -ne $LASTEXITCODE) { throw "exit code $LASTEXITCODE" }
}

# Step 3: MuPDF
Invoke-IDPStep -Name "Installing MuPDF" -Action {
    & "$ScriptDir\install-mupdf.ps1" -InstallDir $InstallDir
    if ($LASTEXITCODE -ne 0 -and $null -ne $LASTEXITCODE) { throw "exit code $LASTEXITCODE" }
}

# Step 4: ONNX Runtime
Invoke-IDPStep -Name "Installing ONNX Runtime" -Action {
    $onnxArgs = @{ InstallDir = $InstallDir }
    if ($GPU) { $onnxArgs.GPU = $true }
    & "$ScriptDir\install-onnxruntime.ps1" @onnxArgs
    if ($LASTEXITCODE -ne 0 -and $null -ne $LASTEXITCODE) { throw "exit code $LASTEXITCODE" }
}

# Step 5: ML Models (DETR + Nemotron + CLIP)
Invoke-IDPStep -Name "Installing ML Models" -Action {
    $modelArgs = @{ InstallDir = $InstallDir }
    if ($System) { $modelArgs.System = $true }
    & "$ScriptDir\install-models.ps1" @modelArgs
    if ($LASTEXITCODE -ne 0 -and $null -ne $LASTEXITCODE) { throw "exit code $LASTEXITCODE" }
}

# Step 6 (optional): LLM for IDP
if ($WithLLM) {
    Invoke-IDPStep -Name "Installing LLM for IDP" -Action {
        & "$ScriptDir\install-slm.ps1" -InstallDir $InstallDir
        if ($LASTEXITCODE -ne 0 -and $null -ne $LASTEXITCODE) { throw "exit code $LASTEXITCODE" }
    }
}

# ── Set CGO env vars ──────────────────────────────────────────────────────────
Write-Host ""
Write-Host "Setting CGO environment variables..." -ForegroundColor Yellow

# Windows tarballs use include/opencv2/; detect which layout is present
$opencvInc = if (Test-Path "$InstallDir\lib\opencv\include\opencv4") {
    "$InstallDir/lib/opencv/include/opencv4"
} else {
    "$InstallDir/lib/opencv/include"
}
$opencvLib  = "$InstallDir/lib/opencv/lib"
$mupdfInc   = "$InstallDir/lib/mupdf/include"
$mupdfLib   = "$InstallDir/lib/mupdf/lib"
$tessInc    = "$InstallDir/tesseract/include"
$tessLib    = "$InstallDir/tesseract/lib"

$CGO_CFLAGS  = "-I$opencvInc -I$mupdfInc -I$tessInc"
$CGO_LDFLAGS = "-L$opencvLib -L$mupdfLib -L$tessLib"

Set-UserEnv -Name "CGO_CFLAGS"  -Value $CGO_CFLAGS
Set-UserEnv -Name "CGO_LDFLAGS" -Value $CGO_LDFLAGS

Write-Host "  CGO_CFLAGS: $CGO_CFLAGS" -ForegroundColor Green
Write-Host "  CGO_LDFLAGS: $CGO_LDFLAGS" -ForegroundColor Green
Write-Host ""

# ── Summary ───────────────────────────────────────────────────────────────────
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
Write-Host "  - MinGW-w64    - CGO compilation toolchain"
Write-Host "  - OpenCV       - Image processing"
Write-Host "  - Tesseract    - OCR engine"
Write-Host "  - Leptonica    - Image library"
Write-Host "  - MuPDF        - PDF processing (static libs)"
Write-Host "  - ONNX Runtime - Model inference"
Write-Host "  - DETR model   - Layout detection"
Write-Host "  - Nemotron     - Table extraction"
Write-Host "  - CLIP model   - Vision embedding"
if ($WithLLM) {
    Write-Host "  - LLM          - Advanced document understanding"
}
Write-Host ""

if ($script:InstallFailed) { exit 1 }
