#
# Faria Installation Verification Script for Windows
# Checks all required and optional components
#
# Usage: .\verify.ps1 [-InstallDir DIR]
#

param(
    [string]$InstallDir = "$env:USERPROFILE\.faria",
    [switch]$Help
)

if ($Help) {
    Write-Host "Faria Installation Verification Script"
    Write-Host ""
    Write-Host "Usage: .\verify.ps1 [OPTIONS]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -InstallDir DIR  Check installation in DIR (default: $env:USERPROFILE\.faria)"
    Write-Host "  -Help            Show this help message"
    exit 0
}

Write-Host "========================================" -ForegroundColor Blue
Write-Host "  Faria Installation Verification" -ForegroundColor Blue
Write-Host "========================================" -ForegroundColor Blue
Write-Host ""

# System info
$Arch = [System.Environment]::GetEnvironmentVariable("PROCESSOR_ARCHITECTURE")

Write-Host "System Information:" -ForegroundColor Yellow
Write-Host "  OS: Windows"
Write-Host "  Architecture: $Arch"
Write-Host "  Install directory: $InstallDir"
Write-Host ""

# Track overall status
$AllRequiredOK = $true
$MissingComponents = @()

Write-Host "Checking components..." -ForegroundColor Yellow
Write-Host ""

# ============================================================================
# Check ONNX Runtime
# ============================================================================
Write-Host "ONNX Runtime:" -ForegroundColor Blue

$LibName = "onnxruntime.dll"
$OnnxPath = $env:FARIA_ONNXRUNTIME_PATH

if (-not $OnnxPath -or -not (Test-Path $OnnxPath)) {
    $OnnxPath = "$InstallDir\lib\onnxruntime\$LibName"
}

if (Test-Path $OnnxPath) {
    $LibSize = [math]::Round((Get-Item $OnnxPath).Length / 1MB, 1)
    Write-Host "  [OK] Found ($LibSize MB)" -ForegroundColor Green
    Write-Host "     $OnnxPath"
} else {
    Write-Host "  [X] Not found" -ForegroundColor Red
    Write-Host "     Expected: $InstallDir\lib\onnxruntime\$LibName"
    $AllRequiredOK = $false
    $MissingComponents += "ONNX Runtime"
}
Write-Host ""

# ============================================================================
# Check DETR Model
# ============================================================================
Write-Host "DETR Model (Layout Detection):" -ForegroundColor Blue

$DETRPath = $env:FARIA_DETR_MODEL_PATH

if (-not $DETRPath -or -not (Test-Path $DETRPath)) {
    $DETRPath = "$InstallDir\models\detr_layout_detection.onnx"
}

if (Test-Path $DETRPath) {
    $ModelSize = [math]::Round((Get-Item $DETRPath).Length / 1MB, 1)
    Write-Host "  [OK] Found ($ModelSize MB)" -ForegroundColor Green
    Write-Host "     $DETRPath"
} else {
    Write-Host "  [X] Not found" -ForegroundColor Red
    Write-Host "     Expected: $InstallDir\models\detr_layout_detection.onnx"
    $AllRequiredOK = $false
    $MissingComponents += "DETR Model"
}
Write-Host ""

# ============================================================================
# Check Nemotron Model
# ============================================================================
Write-Host "Nemotron Model (Table Structure):" -ForegroundColor Blue

$NemotronPath = $env:FARIA_NEMOTRON_MODEL_PATH

if (-not $NemotronPath -or -not (Test-Path $NemotronPath)) {
    $NemotronPath = "$InstallDir\models\nemotron_table_structure.onnx"
}

if (Test-Path $NemotronPath) {
    $ModelSize = [math]::Round((Get-Item $NemotronPath).Length / 1MB, 1)
    Write-Host "  [OK] Found ($ModelSize MB)" -ForegroundColor Green
    Write-Host "     $NemotronPath"
} else {
    Write-Host "  [X] Not found" -ForegroundColor Red
    Write-Host "     Expected: $InstallDir\models\nemotron_table_structure.onnx"
    $AllRequiredOK = $false
    $MissingComponents += "Nemotron Model"
}
Write-Host ""

# ============================================================================
# Check Tesseract OCR
# ============================================================================
Write-Host "Tesseract OCR:" -ForegroundColor Blue

$TesseractCmd = Get-Command tesseract -ErrorAction SilentlyContinue

if ($TesseractCmd) {
    $TesseractVersion = (& tesseract --version 2>&1 | Select-Object -First 1) -replace 'tesseract ', ''
    Write-Host "  [OK] Found ($TesseractVersion)" -ForegroundColor Green
    Write-Host "     $($TesseractCmd.Source)"
} else {
    Write-Host "  [X] Not found" -ForegroundColor Red
    Write-Host "     Install from: https://github.com/UB-Mannheim/tesseract/wiki"
    $AllRequiredOK = $false
    $MissingComponents += "Tesseract"
}
Write-Host ""

# ============================================================================
# Check LLM Components (Optional)
# ============================================================================
Write-Host "LLM Components (Optional):" -ForegroundColor Blue

# Check llama-cli
$LlamaPath = $env:FARIA_LLAMA_CLI_PATH

if (-not $LlamaPath -or -not (Test-Path $LlamaPath)) {
    $LlamaPath = "$InstallDir\bin\llama-cli.exe"
}

if (Test-Path $LlamaPath) {
    Write-Host "  [OK] llama-cli: Found" -ForegroundColor Green
    Write-Host "     $LlamaPath"
} else {
    Write-Host "  [!] llama-cli: Not found (optional)" -ForegroundColor Yellow
}

# Check Qwen model
$QwenPath = $env:FARIA_SLM_MODEL_PATH

if (-not $QwenPath -or -not (Test-Path $QwenPath)) {
    $QwenPath = "$InstallDir\models\qwen2.5-0.5b-instruct-q8_0.gguf"
}

if (Test-Path $QwenPath) {
    $ModelSize = [math]::Round((Get-Item $QwenPath).Length / 1MB, 1)
    Write-Host "  [OK] Qwen model: Found ($ModelSize MB)" -ForegroundColor Green
    Write-Host "     $QwenPath"
} else {
    Write-Host "  [!] Qwen model: Not found (optional)" -ForegroundColor Yellow
}
Write-Host ""

# ============================================================================
# Summary
# ============================================================================
Write-Host "========================================" -ForegroundColor Blue

if ($AllRequiredOK) {
    Write-Host "  All required components installed!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Blue
    Write-Host ""
    Write-Host "Environment variables (optional):" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  `$env:FARIA_ONNXRUNTIME_PATH = `"$OnnxPath`""
    Write-Host "  `$env:FARIA_DETR_MODEL_PATH = `"$DETRPath`""
    Write-Host "  `$env:FARIA_NEMOTRON_MODEL_PATH = `"$NemotronPath`""
    if (Test-Path $LlamaPath) {
        Write-Host "  `$env:FARIA_LLAMA_CLI_PATH = `"$LlamaPath`""
    }
    if (Test-Path $QwenPath) {
        Write-Host "  `$env:FARIA_SLM_MODEL_PATH = `"$QwenPath`""
    }
    Write-Host ""
    Write-Host "Faria is ready to use!" -ForegroundColor Green
} else {
    Write-Host "  Missing required components!" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Blue
    Write-Host ""
    Write-Host "Missing: $($MissingComponents -join ', ')" -ForegroundColor Red
    Write-Host ""
    Write-Host "Run the installation scripts to install missing components:"
    Write-Host "  .\scripts\install.ps1"
    Write-Host ""
    exit 1
}
Write-Host ""
