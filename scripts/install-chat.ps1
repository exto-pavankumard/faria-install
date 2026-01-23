#
# Faria Chat Installation Script
# Orchestrates installation of Chat feature dependencies:
#   - llama.cpp (LLM inference engine)
#   - Qwen 2.5 model (language model)
#
# Usage: .\install-chat.ps1 [OPTIONS]
#

param(
    [string]$InstallDir = "$env:USERPROFILE\.faria",
    [switch]$Help
)

if ($Help) {
    Write-Host "Faria Chat Installation Script"
    Write-Host ""
    Write-Host "Usage: .\install-chat.ps1 [OPTIONS]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -InstallDir DIR  Install to DIR (default: $env:USERPROFILE\.faria)"
    Write-Host "  -Help            Show this help message"
    Write-Host ""
    Write-Host "This script installs dependencies for the Chat feature:"
    Write-Host "  - llama.cpp        LLM inference engine (~5 MB)"
    Write-Host "  - Qwen 2.5-0.5B    Language model (~530 MB)"
    exit 0
}

# Get script directory
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "   Faria Chat Dependencies Installation" -ForegroundColor Blue
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Install directory: $InstallDir" -ForegroundColor Yellow
Write-Host ""

# Create install directory
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null

# Track installation status
$InstallFailed = $false

Write-Host "-----------------------------------------------------------------" -ForegroundColor Blue
Write-Host "  Installing LLM Components (llama.cpp + Qwen)" -ForegroundColor Blue
Write-Host "-----------------------------------------------------------------" -ForegroundColor Blue
Write-Host ""

try {
    & "$ScriptDir\install-slm.ps1" -InstallDir $InstallDir
    if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) {
        throw "Script returned exit code $LASTEXITCODE"
    }
    Write-Host "[OK] LLM Components installed successfully" -ForegroundColor Green
} catch {
    Write-Host "[X] LLM Components installation failed: $_" -ForegroundColor Red
    $InstallFailed = $true
}

# Final Summary
Write-Host ""
Write-Host "=================================================================" -ForegroundColor Cyan
if (-not $InstallFailed) {
    Write-Host "   Chat Dependencies Installed Successfully!" -ForegroundColor Green
} else {
    Write-Host "   Chat Installation Completed with Warnings" -ForegroundColor Yellow
}
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Installed components:" -ForegroundColor Yellow
Write-Host "  - llama.cpp    - LLM inference engine"
Write-Host "  - Qwen 2.5     - Language model for chat and cross-page table merging"
Write-Host ""

if ($InstallFailed) {
    exit 1
}
