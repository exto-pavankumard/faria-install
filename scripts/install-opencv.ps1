#
# Faria OpenCV Installation Script for Windows
# Downloads pre-built OpenCV tarball (MinGW-w64) and registers pkg-config
#
# Usage: .\install-opencv.ps1 [-InstallDir DIR]
#

param(
    [string]$InstallDir = "$env:USERPROFILE\.faria",
    [switch]$Force,
    [switch]$Help
)

if ($Help) {
    Write-Host "Faria OpenCV Installation Script"
    Write-Host ""
    Write-Host "Usage: .\install-opencv.ps1 [OPTIONS]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -InstallDir DIR  Install to DIR (default: $env:USERPROFILE\.faria)"
    Write-Host "  -Force           Reinstall even if already present"
    Write-Host "  -Help            Show this help message"
    exit 0
}

$OpenCVVersion = "4.12.0"
$OpenCVDir     = "$InstallDir\lib\opencv"
$PkgConfigDir  = "C:\msys64\mingw64\lib\pkgconfig"

# Asset hosted in faria-install GitHub Releases
$OpenCVAsset   = "opencv-$OpenCVVersion-windows-x86_64.zip"
$OpenCVUrl     = "https://github.com/exto360-inc/faria-install/releases/download/opencv-$OpenCVVersion/$OpenCVAsset"
$ChecksumsUrl  = "https://github.com/exto360-inc/faria-install/releases/download/opencv-$OpenCVVersion/checksums.txt"

Write-Host "========================================" -ForegroundColor Blue
Write-Host "  Faria OpenCV Installation" -ForegroundColor Blue
Write-Host "========================================" -ForegroundColor Blue
Write-Host ""

$Arch = [System.Environment]::GetEnvironmentVariable("PROCESSOR_ARCHITECTURE")
Write-Host "Architecture: $Arch"
Write-Host "Install directory: $OpenCVDir"
Write-Host ""

if ($Arch -ne "AMD64") {
    Write-Host "Error: Only x86_64 (AMD64) Windows is supported for OpenCV CGO builds." -ForegroundColor Red
    exit 1
}

# ── Already installed? ────────────────────────────────────────────────────────
$dllPath = "$OpenCVDir\bin\libopencv_world41200.dll"
if ((Test-Path $dllPath) -and -not $Force) {
    Write-Host "OpenCV $OpenCVVersion already installed at $OpenCVDir" -ForegroundColor Green
    exit 0
}

New-Item -ItemType Directory -Force -Path $OpenCVDir | Out-Null
$TempDir = Join-Path $env:TEMP "faria-opencv-$(Get-Random)"
New-Item -ItemType Directory -Force -Path $TempDir | Out-Null

try {
    # ── Download tarball ──────────────────────────────────────────────────────
    Write-Host "Downloading OpenCV $OpenCVVersion pre-built tarball..." -ForegroundColor Yellow
    Write-Host "  URL: $OpenCVUrl"
    $ZipPath = Join-Path $TempDir $OpenCVAsset
    Start-BitsDownload -Url $OpenCVUrl -Destination $ZipPath -Description "OpenCV $OpenCVVersion"
    Write-Host "  Download complete." -ForegroundColor Green
    Write-Host ""

    # ── Checksum verification ─────────────────────────────────────────────────
    Write-Host "Verifying checksum..." -ForegroundColor Yellow
    $ChecksumsPath = Join-Path $TempDir "checksums.txt"
    Invoke-WebRequest -Uri $ChecksumsUrl -OutFile $ChecksumsPath -UseBasicParsing
    $checksumLine = Get-Content $ChecksumsPath | Where-Object { $_ -match [regex]::Escape($OpenCVAsset) }
    if ($checksumLine) {
        $expectedHash = ($checksumLine -split '\s+')[0]
        Invoke-ChecksumVerify -FilePath $ZipPath -ExpectedHash $expectedHash
        Write-Host "  Checksum OK." -ForegroundColor Green
    } else {
        Write-Host "  Warning: no checksum entry found for $OpenCVAsset — skipping verify." -ForegroundColor Yellow
    }
    Write-Host ""

    # ── Extract ───────────────────────────────────────────────────────────────
    Write-Host "Extracting OpenCV..." -ForegroundColor Yellow
    $ExtractDir = Join-Path $TempDir "opencv-extract"
    Expand-Archive -Path $ZipPath -DestinationPath $ExtractDir -Force

    # Move contents into install location
    if (Test-Path $OpenCVDir) { Remove-Item -Recurse -Force $OpenCVDir }
    $inner = Get-ChildItem -Path $ExtractDir -Directory | Select-Object -First 1
    if ($inner) {
        Move-Item -Path $inner.FullName -Destination $OpenCVDir -Force
    } else {
        # Flat archive — contents go directly into $OpenCVDir
        Move-Item -Path $ExtractDir -Destination $OpenCVDir -Force
    }
    Write-Host "  Extracted to: $OpenCVDir" -ForegroundColor Green
    Write-Host ""

    # ── Register pkg-config ───────────────────────────────────────────────────
    $PcSrc = "$OpenCVDir\lib\pkgconfig\opencv4.pc"
    if (Test-Path $PcSrc) {
        Write-Host "Registering opencv4.pc with pkg-config..." -ForegroundColor Yellow
        New-Item -ItemType Directory -Force -Path $PkgConfigDir | Out-Null
        $PcDest = "$PkgConfigDir\opencv4.pc"
        Copy-Item $PcSrc $PcDest -Force
        # Fix prefix to point at actual install location (use forward slashes for pkg-config)
        $prefix = ($OpenCVDir -replace '\\', '/').TrimEnd('/')
        (Get-Content $PcDest) -replace 'prefix=.*', "prefix=$prefix" |
            Set-Content $PcDest
        Write-Host "  opencv4.pc registered." -ForegroundColor Green
        Write-Host ""
    } else {
        Write-Host "Warning: $PcSrc not found — pkg-config not registered." -ForegroundColor Yellow
    }

    # ── Verify ────────────────────────────────────────────────────────────────
    Write-Host "Verifying installation..." -ForegroundColor Yellow
    $dll = Get-ChildItem -Path "$OpenCVDir\bin" -Filter "libopencv_world*.dll" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($dll) {
        Write-Host "  OpenCV DLL: $($dll.Name)" -ForegroundColor Green
    } else {
        Write-Host "  Warning: OpenCV DLL not found under $OpenCVDir\bin" -ForegroundColor Yellow
    }

    $pkgTest = Get-Command pkg-config -ErrorAction SilentlyContinue
    if ($pkgTest) {
        $pcOk = & pkg-config --exists opencv4 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  pkg-config --exists opencv4: OK" -ForegroundColor Green
        } else {
            Write-Host "  pkg-config --exists opencv4: FAILED (may need new shell session)" -ForegroundColor Yellow
        }
    }

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  OpenCV Installation Complete!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Installed to: $OpenCVDir"
    Write-Host ""

} finally {
    Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue
}
