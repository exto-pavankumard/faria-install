#
# Faria SLM Installation Script for Windows
# Downloads and installs llama-cli and Qwen model for SLM features
#
# Usage: .\install-slm.ps1 [-InstallDir DIR]
#
# Default install location: $env:USERPROFILE\.faria\
#

param(
    [string]$InstallDir = "$env:USERPROFILE\.faria",
    [switch]$Help
)

if (-not (Get-Command 'Set-UserEnv' -ErrorAction SilentlyContinue)) {
    . (Join-Path $PSScriptRoot '_common.ps1')
}

# Configuration
$LlamaCppVersion = "b4549"
$QwenModel = "qwen2.5-0.5b-instruct-q8_0.gguf"
$QwenModelUrl = "https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/$QwenModel"

if ($Help) {
    Write-Host "Faria SLM Installation Script"
    Write-Host ""
    Write-Host "Usage: .\install-slm.ps1 [OPTIONS]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -InstallDir DIR  Install to DIR (default: $env:USERPROFILE\.faria)"
    Write-Host "  -Help            Show this help message"
    exit 0
}

Write-Host "========================================" -ForegroundColor Blue
Write-Host "  Faria SLM Installation Script" -ForegroundColor Blue
Write-Host "========================================" -ForegroundColor Blue
Write-Host ""

# Detect architecture
$Arch = [System.Environment]::GetEnvironmentVariable("PROCESSOR_ARCHITECTURE")

Write-Host "Detecting system..." -ForegroundColor Yellow
Write-Host "  OS: Windows"
Write-Host "  Architecture: $Arch"

# Determine llama.cpp release asset name
switch ($Arch) {
    "AMD64" {
        $LlamaAsset = "llama-$LlamaCppVersion-bin-win-llvm-x64.zip"
    }
    "ARM64" {
        $LlamaAsset = "llama-$LlamaCppVersion-bin-win-llvm-arm64.zip"
    }
    default {
        Write-Host "Unsupported architecture: $Arch" -ForegroundColor Red
        exit 1
    }
}

$LlamaUrl = "https://github.com/ggerganov/llama.cpp/releases/download/$LlamaCppVersion/$LlamaAsset"

Write-Host ""
Write-Host "Installation configuration:" -ForegroundColor Yellow
Write-Host "  Install directory: $InstallDir"
Write-Host "  llama.cpp version: $LlamaCppVersion"
Write-Host "  Model: $QwenModel"
Write-Host ""

# Create directories
Write-Host "Creating directories..." -ForegroundColor Yellow
New-Item -ItemType Directory -Force -Path "$InstallDir\bin" | Out-Null
New-Item -ItemType Directory -Force -Path "$InstallDir\models" | Out-Null

# Create temp directory
$TempDir = Join-Path $env:TEMP "faria-install-$(Get-Random)"
New-Item -ItemType Directory -Force -Path $TempDir | Out-Null

try {
    # Download llama.cpp
    Write-Host ""
    Write-Host "Downloading llama.cpp..." -ForegroundColor Yellow
    Write-Host "  URL: $LlamaUrl"

    $LlamaZipPath = Join-Path $TempDir "llama.zip"

    Start-BitsDownload -Url $LlamaUrl -Destination $LlamaZipPath -Description "llama.cpp $LlamaCppVersion"

    Write-Host "Extracting llama.cpp..." -ForegroundColor Yellow
    $LlamaExtractPath = Join-Path $TempDir "llama"
    Expand-Archive -Path $LlamaZipPath -DestinationPath $LlamaExtractPath -Force

    # Find and copy llama-cli.exe
    $LlamaCli = Get-ChildItem -Path $LlamaExtractPath -Recurse -Filter "llama-cli.exe" | Select-Object -First 1

    if (-not $LlamaCli) {
        Write-Host "Error: llama-cli.exe not found in archive" -ForegroundColor Red
        exit 1
    }

    Copy-Item -Path $LlamaCli.FullName -Destination "$InstallDir\bin\llama-cli.exe" -Force
    Write-Host "  Installed: $InstallDir\bin\llama-cli.exe" -ForegroundColor Green

    # Download Qwen model
    Write-Host ""
    Write-Host "Downloading Qwen model (this may take a while)..." -ForegroundColor Yellow
    Write-Host "  URL: $QwenModelUrl"
    Write-Host "  Size: ~530MB"

    $ModelPath = "$InstallDir\models\$QwenModel"

    if (Test-Path $ModelPath) {
        Write-Host "  Model already exists, skipping download" -ForegroundColor Yellow
    } else {
        Start-BitsDownload -Url $QwenModelUrl -Destination $ModelPath -Description "Qwen2.5 0.5B model (~530 MB)"
        Write-Host "  Downloaded: $ModelPath" -ForegroundColor Green
    }

    # Verify installation
    Write-Host ""
    Write-Host "Verifying installation..." -ForegroundColor Yellow

    if (Test-Path "$InstallDir\bin\llama-cli.exe") {
        Write-Host "  llama-cli: OK" -ForegroundColor Green
    } else {
        Write-Host "  llama-cli: FAILED" -ForegroundColor Red
        exit 1
    }

    if (Test-Path $ModelPath) {
        $ModelSize = (Get-Item $ModelPath).Length / 1MB
        Write-Host "  Model: OK ($([math]::Round($ModelSize, 1)) MB)" -ForegroundColor Green
    } else {
        Write-Host "  Model: FAILED" -ForegroundColor Red
        exit 1
    }

    # Persist env vars to User registry (consistent with IDP install behaviour)
    Set-UserEnv -Name "FARIA_LLAMA_CLI_PATH" -Value "$InstallDir\bin\llama-cli.exe"
    Set-UserEnv -Name "FARIA_SLM_MODEL_PATH"  -Value "$InstallDir\models\$QwenModel"
    Write-Host "FARIA_LLAMA_CLI_PATH set to: $InstallDir\bin\llama-cli.exe" -ForegroundColor Green
    Write-Host "FARIA_SLM_MODEL_PATH  set to: $InstallDir\models\$QwenModel" -ForegroundColor Green

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  Installation Complete!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Installed files:"
    Write-Host "  $InstallDir\bin\llama-cli.exe"
    Write-Host "  $InstallDir\models\$QwenModel"
    Write-Host ""
    Write-Host "Environment variables set (User registry):"
    Write-Host "  FARIA_LLAMA_CLI_PATH = $InstallDir\bin\llama-cli.exe"
    Write-Host "  FARIA_SLM_MODEL_PATH  = $InstallDir\models\$QwenModel"
    Write-Host ""
    Write-Host "Open a new PowerShell session for the changes to take effect." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Or configure manually in code:"
    Write-Host "  config.Document.SLMConfig = &faria.SLMConfig{"
    Write-Host "      LlamaCLIPath: `"$InstallDir\bin\llama-cli.exe`","
    Write-Host "      ModelPath:    `"$InstallDir\models\$QwenModel`","
    Write-Host "  }"
    Write-Host ""

} finally {
    # Cleanup
    if (Test-Path $TempDir) {
        Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
