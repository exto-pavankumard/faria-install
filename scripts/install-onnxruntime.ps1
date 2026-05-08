#
# Faria ONNX Runtime Installation Script for Windows
# Downloads and installs ONNX Runtime with optional CUDA support
#
# Usage: .\install-onnxruntime.ps1 [-InstallDir DIR] [-GPU]
#

param(
    [string]$InstallDir = "$env:USERPROFILE\.faria",
    [switch]$GPU,
    [switch]$Force,
    [switch]$Help
)

$OnnxRuntimeVersion = "1.22.0"

if ($Help) {
    Write-Host "Faria ONNX Runtime Installation Script"
    Write-Host ""
    Write-Host "Usage: .\install-onnxruntime.ps1 [OPTIONS]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -InstallDir DIR  Install to DIR (default: $env:USERPROFILE\.faria)"
    Write-Host "  -GPU             Install GPU/CUDA version"
    Write-Host "  -Force           Reinstall even if already present"
    Write-Host "  -Help            Show this help message"
    exit 0
}

Write-Host "========================================" -ForegroundColor Blue
Write-Host "  Faria ONNX Runtime Installation" -ForegroundColor Blue
Write-Host "========================================" -ForegroundColor Blue
Write-Host ""

$Arch = [System.Environment]::GetEnvironmentVariable("PROCESSOR_ARCHITECTURE")
Write-Host "Architecture: $Arch"
Write-Host "GPU enabled: $GPU"
Write-Host ""

# ── CUDA pre-check ────────────────────────────────────────────────────────────
if ($GPU) {
    $nvidiaSmi = Get-Command nvidia-smi -ErrorAction SilentlyContinue
    if (-not $nvidiaSmi) {
        Write-Host "Error: -GPU requested but nvidia-smi not found." -ForegroundColor Red
        Write-Host "Install CUDA Toolkit 11.8+ from https://developer.nvidia.com/cuda-downloads"
        exit 1
    }
    $cudaVersion = (& nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>&1 | Select-Object -First 1)
    Write-Host "CUDA driver detected: $cudaVersion" -ForegroundColor Green
    Write-Host ""
}

# ── Determine asset name ──────────────────────────────────────────────────────
switch ($Arch) {
    "AMD64" {
        $OnnxAsset = if ($GPU) {
            "onnxruntime-win-x64-gpu-$OnnxRuntimeVersion.zip"
        } else {
            "onnxruntime-win-x64-$OnnxRuntimeVersion.zip"
        }
        $LibName = "onnxruntime.dll"
    }
    "ARM64" {
        if ($GPU) {
            Write-Host "Warning: GPU not available for ARM64 Windows, using CPU version." -ForegroundColor Yellow
        }
        $OnnxAsset = "onnxruntime-win-arm64-$OnnxRuntimeVersion.zip"
        $LibName = "onnxruntime.dll"
    }
    default {
        Write-Host "Unsupported architecture: $Arch" -ForegroundColor Red
        exit 1
    }
}

$OnnxUrl      = "https://github.com/microsoft/onnxruntime/releases/download/v$OnnxRuntimeVersion/$OnnxAsset"
$OnnxLibDir   = "$InstallDir\lib\onnxruntime"
$LibPath      = "$OnnxLibDir\$LibName"

Write-Host "ONNX Runtime version: $OnnxRuntimeVersion"
Write-Host "Asset: $OnnxAsset"
Write-Host "Install directory: $OnnxLibDir"
Write-Host ""

# ── Already installed? ────────────────────────────────────────────────────────
if ((Test-Path $LibPath) -and -not $Force) {
    $libSize = [math]::Round((Get-Item $LibPath).Length / 1MB, 1)
    Write-Host "ONNX Runtime already installed: $LibPath ($libSize MB)" -ForegroundColor Green
    exit 0
}

New-Item -ItemType Directory -Force -Path $OnnxLibDir | Out-Null
$TempDir = Join-Path $env:TEMP "faria-onnx-$(Get-Random)"
New-Item -ItemType Directory -Force -Path $TempDir | Out-Null

try {
    # ── Download ──────────────────────────────────────────────────────────────
    Write-Host "Downloading ONNX Runtime..." -ForegroundColor Yellow
    Write-Host "  URL: $OnnxUrl"
    $OnnxZipPath = Join-Path $TempDir "onnxruntime.zip"
    Start-BitsDownload -Url $OnnxUrl -Destination $OnnxZipPath -Description "ONNX Runtime $OnnxRuntimeVersion"
    Write-Host "  Download complete." -ForegroundColor Green
    Write-Host ""

    # ── Checksum verification ─────────────────────────────────────────────────
    Write-Host "Verifying checksum..." -ForegroundColor Yellow
    $ChecksumsUrl  = "https://github.com/microsoft/onnxruntime/releases/download/v$OnnxRuntimeVersion/checksums.txt"
    $ChecksumsPath = Join-Path $TempDir "checksums.txt"
    try {
        Invoke-WebRequest -Uri $ChecksumsUrl -OutFile $ChecksumsPath -UseBasicParsing
        $checksumLine = Get-Content $ChecksumsPath | Where-Object { $_ -match [regex]::Escape($OnnxAsset) }
        if ($checksumLine) {
            $expectedHash = ($checksumLine -split '\s+')[0]
            Invoke-ChecksumVerify -FilePath $OnnxZipPath -ExpectedHash $expectedHash
            Write-Host "  Checksum OK." -ForegroundColor Green
        } else {
            Write-Host "  Warning: no entry for $OnnxAsset in checksums.txt — skipping verify." -ForegroundColor Yellow
        }
    } catch {
        Write-Host "  Warning: checksum file unavailable — skipping verify. ($_)" -ForegroundColor Yellow
    }
    Write-Host ""

    # ── Extract ───────────────────────────────────────────────────────────────
    Write-Host "Extracting ONNX Runtime..." -ForegroundColor Yellow
    $OnnxExtractPath = Join-Path $TempDir "onnxruntime"
    Expand-Archive -Path $OnnxZipPath -DestinationPath $OnnxExtractPath -Force

    $ExtractedDir = Get-ChildItem -Path $OnnxExtractPath -Directory |
        Where-Object { $_.Name -like "onnxruntime-*" } | Select-Object -First 1

    if (-not $ExtractedDir) {
        Write-Host "Error: Could not find extracted ONNX Runtime directory." -ForegroundColor Red
        exit 1
    }

    Copy-Item -Path "$($ExtractedDir.FullName)\lib\*" -Destination $OnnxLibDir -Recurse -Force
    Write-Host "  Extracted to: $OnnxLibDir" -ForegroundColor Green
    Write-Host ""

    # ── Persist env var ───────────────────────────────────────────────────────
    Set-UserEnv -Name "FARIA_ONNXRUNTIME_PATH" -Value $LibPath
    Write-Host "FARIA_ONNXRUNTIME_PATH set to: $LibPath" -ForegroundColor Green
    Write-Host ""

    # ── Verify ────────────────────────────────────────────────────────────────
    Write-Host "Verifying installation..." -ForegroundColor Yellow
    if (Test-Path $LibPath) {
        $libSize = [math]::Round((Get-Item $LibPath).Length / 1MB, 1)
        Write-Host "  $LibName`: OK ($libSize MB)" -ForegroundColor Green
    } else {
        Write-Host "  $LibName`: FAILED" -ForegroundColor Red
        exit 1
    }

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  ONNX Runtime Installation Complete!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Installed: $LibPath"
    Write-Host ""
    if ($GPU) {
        Write-Host "Note: CUDA GPU acceleration enabled. Ensure CUDA Toolkit 11.8+ is installed." -ForegroundColor Blue
        Write-Host ""
    }

} finally {
    Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue
}
