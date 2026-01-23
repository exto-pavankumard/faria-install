#
# Faria ONNX Runtime Installation Script for Windows
# Downloads and installs ONNX Runtime with optional CUDA support
#
# Usage: .\install-onnxruntime.ps1 [-InstallDir DIR] [-GPU]
#
# Default install location: $env:USERPROFILE\.faria\
#

param(
    [string]$InstallDir = "$env:USERPROFILE\.faria",
    [switch]$GPU,
    [switch]$Help
)

# Configuration
$OnnxRuntimeVersion = "1.22.0"

if ($Help) {
    Write-Host "Faria ONNX Runtime Installation Script"
    Write-Host ""
    Write-Host "Usage: .\install-onnxruntime.ps1 [OPTIONS]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -InstallDir DIR  Install to DIR (default: $env:USERPROFILE\.faria)"
    Write-Host "  -GPU             Install GPU/CUDA version"
    Write-Host "  -Help            Show this help message"
    exit 0
}

Write-Host "========================================" -ForegroundColor Blue
Write-Host "  Faria ONNX Runtime Installation" -ForegroundColor Blue
Write-Host "========================================" -ForegroundColor Blue
Write-Host ""

# Detect architecture
$Arch = [System.Environment]::GetEnvironmentVariable("PROCESSOR_ARCHITECTURE")

Write-Host "Detecting system..." -ForegroundColor Yellow
Write-Host "  OS: Windows"
Write-Host "  Architecture: $Arch"
Write-Host "  GPU enabled: $GPU"

# Determine ONNX Runtime release asset name
switch ($Arch) {
    "AMD64" {
        if ($GPU) {
            $OnnxAsset = "onnxruntime-win-x64-gpu-$OnnxRuntimeVersion.zip"
        } else {
            $OnnxAsset = "onnxruntime-win-x64-$OnnxRuntimeVersion.zip"
        }
        $LibName = "onnxruntime.dll"
    }
    "ARM64" {
        if ($GPU) {
            Write-Host "Warning: GPU version not available for ARM64 Windows, using CPU version" -ForegroundColor Yellow
        }
        $OnnxAsset = "onnxruntime-win-arm64-$OnnxRuntimeVersion.zip"
        $LibName = "onnxruntime.dll"
    }
    default {
        Write-Host "Unsupported architecture: $Arch" -ForegroundColor Red
        exit 1
    }
}

$OnnxUrl = "https://github.com/microsoft/onnxruntime/releases/download/v$OnnxRuntimeVersion/$OnnxAsset"

Write-Host ""
Write-Host "Installation configuration:" -ForegroundColor Yellow
Write-Host "  Install directory: $InstallDir"
Write-Host "  ONNX Runtime version: $OnnxRuntimeVersion"
Write-Host "  Asset: $OnnxAsset"
Write-Host ""

# Check if already installed
$LibPath = "$InstallDir\lib\onnxruntime\$LibName"
if (Test-Path $LibPath) {
    Write-Host "ONNX Runtime already installed at: $LibPath" -ForegroundColor Yellow
    $response = Read-Host "Do you want to reinstall? (y/N)"
    if ($response -ne 'y' -and $response -ne 'Y') {
        Write-Host "Skipping installation." -ForegroundColor Green
        exit 0
    }
}

# Create directories
Write-Host "Creating directories..." -ForegroundColor Yellow
New-Item -ItemType Directory -Force -Path "$InstallDir\lib\onnxruntime" | Out-Null

# Create temp directory
$TempDir = Join-Path $env:TEMP "faria-onnx-install-$(Get-Random)"
New-Item -ItemType Directory -Force -Path $TempDir | Out-Null

try {
    # Download ONNX Runtime
    Write-Host ""
    Write-Host "Downloading ONNX Runtime..." -ForegroundColor Yellow
    Write-Host "  URL: $OnnxUrl"

    $OnnxZipPath = Join-Path $TempDir "onnxruntime.zip"

    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $OnnxUrl -OutFile $OnnxZipPath -UseBasicParsing
    $ProgressPreference = 'Continue'

    Write-Host "Extracting ONNX Runtime..." -ForegroundColor Yellow
    $OnnxExtractPath = Join-Path $TempDir "onnxruntime"
    Expand-Archive -Path $OnnxZipPath -DestinationPath $OnnxExtractPath -Force

    # Find and copy library files
    $ExtractedDir = Get-ChildItem -Path $OnnxExtractPath -Directory | Where-Object { $_.Name -like "onnxruntime-*" } | Select-Object -First 1

    if (-not $ExtractedDir) {
        Write-Host "Error: Could not find extracted ONNX Runtime directory" -ForegroundColor Red
        exit 1
    }

    # Copy library files
    Write-Host "Installing library files..." -ForegroundColor Yellow
    Copy-Item -Path "$($ExtractedDir.FullName)\lib\*" -Destination "$InstallDir\lib\onnxruntime\" -Recurse -Force

    # Verify installation
    Write-Host ""
    Write-Host "Verifying installation..." -ForegroundColor Yellow

    if (Test-Path $LibPath) {
        $LibSize = (Get-Item $LibPath).Length / 1MB
        Write-Host "  $LibName`: OK ($([math]::Round($LibSize, 1)) MB)" -ForegroundColor Green
    } else {
        Write-Host "  $LibName`: FAILED" -ForegroundColor Red
        exit 1
    }

    # Print success message and instructions
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  Installation Complete!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Installed files:"
    Write-Host "  $InstallDir\lib\onnxruntime\$LibName"
    Write-Host ""
    Write-Host "Configuration Options:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Option 1: Environment variable (recommended)"
    Write-Host "  Run these commands in PowerShell (or add to your profile):"
    Write-Host ""
    Write-Host "    `$env:FARIA_ONNXRUNTIME_PATH = `"$InstallDir\lib\onnxruntime\$LibName`""
    Write-Host ""
    Write-Host "  Or set permanently:"
    Write-Host "    [Environment]::SetEnvironmentVariable('FARIA_ONNXRUNTIME_PATH', '$InstallDir\lib\onnxruntime\$LibName', 'User')"
    Write-Host ""
    Write-Host "Option 2: Auto-detection"
    Write-Host "  Faria will automatically detect files in $env:USERPROFILE\.faria\ (no action needed)"
    Write-Host ""
    Write-Host "Option 3: Manual configuration in code"
    Write-Host "  config.Runtime.ONNXLibraryPath = `"$InstallDir\lib\onnxruntime\$LibName`""
    Write-Host ""

    if ($GPU) {
        Write-Host "Note: CUDA GPU acceleration is enabled. Ensure CUDA Toolkit is installed." -ForegroundColor Blue
    }
    Write-Host ""

} finally {
    # Cleanup
    if (Test-Path $TempDir) {
        Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
