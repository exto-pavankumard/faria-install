#
# Faria Uninstallation Script for Windows
# Removes all Faria-installed files and directories
#
# Usage: .\uninstall.ps1 [-InstallDir DIR] [-Force]
#

param(
    [string]$InstallDir = "$env:USERPROFILE\.faria",
    [switch]$Force,
    [switch]$Help
)

if ($Help) {
    Write-Host "Faria Uninstallation Script"
    Write-Host ""
    Write-Host "Usage: .\uninstall.ps1 [OPTIONS]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -InstallDir DIR  Uninstall from DIR (default: $env:USERPROFILE\.faria)"
    Write-Host "  -Force           Skip confirmation prompt"
    Write-Host "  -Help            Show this help message"
    Write-Host ""
    Write-Host "This script removes:"
    Write-Host "  - All files in the Faria installation directory"
    Write-Host "  - ONNX Runtime library"
    Write-Host "  - DETR and Nemotron models"
    Write-Host "  - llama-cli and Qwen model (if installed)"
    Write-Host ""
    Write-Host "Note: System-installed Tesseract OCR is NOT removed."
    exit 0
}

Write-Host "========================================" -ForegroundColor Blue
Write-Host "  Faria Uninstallation" -ForegroundColor Blue
Write-Host "========================================" -ForegroundColor Blue
Write-Host ""

# Check if installation directory exists
if (-not (Test-Path $InstallDir)) {
    Write-Host "Faria installation directory not found: $InstallDir" -ForegroundColor Yellow
    Write-Host "Nothing to uninstall."
    exit 0
}

# Show what will be removed
Write-Host "The following will be removed:" -ForegroundColor Yellow
Write-Host ""

# List contents
if (Test-Path "$InstallDir\lib") {
    Write-Host "  Libraries:"
    Get-ChildItem -Path "$InstallDir\lib" -Recurse -File | ForEach-Object {
        $size = [math]::Round($_.Length / 1MB, 1)
        Write-Host "    - $($_.FullName) ($size MB)"
    }
}

if (Test-Path "$InstallDir\models") {
    Write-Host "  Models:"
    Get-ChildItem -Path "$InstallDir\models" -Recurse -File | ForEach-Object {
        $size = [math]::Round($_.Length / 1MB, 1)
        Write-Host "    - $($_.FullName) ($size MB)"
    }
}

if (Test-Path "$InstallDir\bin") {
    Write-Host "  Binaries:"
    Get-ChildItem -Path "$InstallDir\bin" -Recurse -File | ForEach-Object {
        Write-Host "    - $($_.FullName)"
    }
}

# Calculate total size
$TotalSize = (Get-ChildItem -Path $InstallDir -Recurse | Measure-Object -Property Length -Sum).Sum
$TotalSizeMB = [math]::Round($TotalSize / 1MB, 1)
Write-Host ""
Write-Host "  Total: $TotalSizeMB MB" -ForegroundColor Yellow
Write-Host ""

# Confirm removal
if (-not $Force) {
    Write-Host "WARNING: This action cannot be undone." -ForegroundColor Red
    $response = Read-Host "Are you sure you want to remove all Faria files? (y/N)"
    if ($response -ne 'y' -and $response -ne 'Y') {
        Write-Host "Uninstallation cancelled."
        exit 0
    }
}

# Remove files
Write-Host ""
Write-Host "Removing Faria files..." -ForegroundColor Yellow

try {
    Remove-Item -Path $InstallDir -Recurse -Force
    Write-Host "[OK] Faria files removed successfully" -ForegroundColor Green
} catch {
    Write-Host "[X] Failed to remove some files: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Uninstallation Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Removed: $InstallDir"
Write-Host ""
Write-Host "Note: System-installed Tesseract OCR was NOT removed." -ForegroundColor Yellow
Write-Host "To remove Tesseract, uninstall it from Control Panel or use:"
Write-Host "  winget uninstall tesseract"
Write-Host ""
Write-Host "Note: Remember to remove environment variables:" -ForegroundColor Yellow
Write-Host "  - FARIA_ONNXRUNTIME_PATH"
Write-Host "  - FARIA_DETR_MODEL_PATH"
Write-Host "  - FARIA_NEMOTRON_MODEL_PATH"
Write-Host "  - FARIA_LLAMA_CLI_PATH"
Write-Host "  - FARIA_SLM_MODEL_PATH"
Write-Host ""
Write-Host "To remove environment variables permanently:"
Write-Host "  [Environment]::SetEnvironmentVariable('FARIA_ONNXRUNTIME_PATH', `$null, 'User')"
Write-Host ""
