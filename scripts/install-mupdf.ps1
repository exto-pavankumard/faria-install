#
# Faria MuPDF Installation Script for Windows
# Downloads pre-built MuPDF dev tarball (MinGW static libs + headers) and
# registers pkg-config
#
# Usage: .\install-mupdf.ps1 [-InstallDir DIR]
#

param(
    [string]$InstallDir = "$env:USERPROFILE\.faria",
    [switch]$Force,
    [switch]$Help
)

if ($Help) {
    Write-Host "Faria MuPDF Installation Script"
    Write-Host ""
    Write-Host "Usage: .\install-mupdf.ps1 [OPTIONS]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -InstallDir DIR  Install to DIR (default: $env:USERPROFILE\.faria)"
    Write-Host "  -Force           Reinstall even if already present"
    Write-Host "  -Help            Show this help message"
    exit 0
}

$MuPDFVersion  = "1.24.9"
$MuPDFDir      = "$InstallDir\lib\mupdf"
$BinDir        = "$InstallDir\bin"

if (-not (Get-Command 'Set-UserEnv' -ErrorAction SilentlyContinue)) {
    . (Join-Path $PSScriptRoot '_common.ps1')
}

$PkgConfigDir = Get-MSYS2PkgConfigDir

# Override FARIA_RELEASE_REPO env var to download from a fork (e.g. for CI on a fork).
$ReleaseRepo   = if ($env:FARIA_RELEASE_REPO) { $env:FARIA_RELEASE_REPO } else { "exto360-inc/faria-install" }
$MuPDFAsset    = "mupdf-$MuPDFVersion-windows-dev-x86_64.zip"
$MuPDFUrl      = "https://github.com/$ReleaseRepo/releases/download/mupdf-$MuPDFVersion/$MuPDFAsset"
$ChecksumsUrl  = "https://github.com/$ReleaseRepo/releases/download/mupdf-$MuPDFVersion/checksums.txt"

Write-Host "========================================" -ForegroundColor Blue
Write-Host "  Faria MuPDF Installation" -ForegroundColor Blue
Write-Host "========================================" -ForegroundColor Blue
Write-Host ""

$Arch = [System.Environment]::GetEnvironmentVariable("PROCESSOR_ARCHITECTURE")
Write-Host "Architecture: $Arch"
Write-Host "Install directory: $MuPDFDir"
Write-Host ""

if ($Arch -ne "AMD64") {
    Write-Host "Error: Only x86_64 (AMD64) Windows is supported for MuPDF CGO builds." -ForegroundColor Red
    exit 1
}

# ── Already installed? ────────────────────────────────────────────────────────
$libPath = "$MuPDFDir\lib\libmupdf.a"
if ((Test-Path $libPath) -and -not $Force) {
    Write-Host "MuPDF $MuPDFVersion already installed at $MuPDFDir" -ForegroundColor Green
    exit 0
}

New-Item -ItemType Directory -Force -Path $MuPDFDir | Out-Null
New-Item -ItemType Directory -Force -Path $BinDir   | Out-Null
$TempDir = Join-Path $env:TEMP "faria-mupdf-$(Get-Random)"
New-Item -ItemType Directory -Force -Path $TempDir | Out-Null

try {
    # ── Download tarball ──────────────────────────────────────────────────────
    Write-Host "Downloading MuPDF $MuPDFVersion dev tarball..." -ForegroundColor Yellow
    Write-Host "  URL: $MuPDFUrl"
    $ZipPath = Join-Path $TempDir $MuPDFAsset
    Start-BitsDownload -Url $MuPDFUrl -Destination $ZipPath -Description "MuPDF $MuPDFVersion"
    Write-Host "  Download complete." -ForegroundColor Green
    Write-Host ""

    # ── Checksum verification ─────────────────────────────────────────────────
    Write-Host "Verifying checksum..." -ForegroundColor Yellow
    $ChecksumsPath = Join-Path $TempDir "checksums.txt"
    Invoke-WebRequest -Uri $ChecksumsUrl -OutFile $ChecksumsPath -UseBasicParsing
    $checksumLine = Get-Content $ChecksumsPath | Where-Object { $_ -match [regex]::Escape($MuPDFAsset) }
    if ($checksumLine) {
        $expectedHash = ($checksumLine -split '\s+')[0]
        Invoke-ChecksumVerify -FilePath $ZipPath -ExpectedHash $expectedHash
        Write-Host "  Checksum OK." -ForegroundColor Green
    } else {
        Write-Host "  Warning: no checksum entry found for $MuPDFAsset — skipping verify." -ForegroundColor Yellow
    }
    Write-Host ""

    # ── Extract ───────────────────────────────────────────────────────────────
    # The zip is flat: include/, lib/, bin/ at root (no top-level wrapper dir).
    Write-Host "Extracting MuPDF..." -ForegroundColor Yellow
    if (Test-Path $MuPDFDir) { Remove-Item -Recurse -Force $MuPDFDir }
    Expand-Archive -Path $ZipPath -DestinationPath $MuPDFDir -Force
    Write-Host "  Extracted to: $MuPDFDir" -ForegroundColor Green

    # Copy mutool.exe to bin/
    $mutoolSrc = "$MuPDFDir\bin\mutool.exe"
    if (Test-Path $mutoolSrc) {
        Copy-Item $mutoolSrc "$BinDir\mutool.exe" -Force
        Write-Host "  mutool.exe copied to $BinDir" -ForegroundColor Green
    }
    Write-Host ""

    # ── Register pkg-config ───────────────────────────────────────────────────
    $PcSrc = "$MuPDFDir\lib\pkgconfig\mupdf.pc"
    if (Test-Path $PcSrc) {
        Write-Host "Registering mupdf.pc with pkg-config..." -ForegroundColor Yellow
        New-Item -ItemType Directory -Force -Path $PkgConfigDir | Out-Null
        $PcDest = "$PkgConfigDir\mupdf.pc"
        Copy-Item $PcSrc $PcDest -Force
        $prefix = ($MuPDFDir -replace '\\', '/').TrimEnd('/')
        (Get-Content $PcDest) -replace 'prefix=.*', "prefix=$prefix" |
            Set-Content $PcDest
        Write-Host "  mupdf.pc registered." -ForegroundColor Green
        Write-Host ""
    } else {
        Write-Host "Warning: $PcSrc not found — pkg-config not registered." -ForegroundColor Yellow
    }

    # ── Verify ────────────────────────────────────────────────────────────────
    Write-Host "Verifying installation..." -ForegroundColor Yellow
    if (Test-Path "$MuPDFDir\lib\libmupdf.a") {
        Write-Host "  libmupdf.a: OK" -ForegroundColor Green
    } else {
        Write-Host "  libmupdf.a: NOT FOUND" -ForegroundColor Red
    }
    if (Test-Path "$MuPDFDir\lib\libmupdf-third.a") {
        Write-Host "  libmupdf-third.a: OK" -ForegroundColor Green
    } else {
        Write-Host "  libmupdf-third.a: NOT FOUND" -ForegroundColor Yellow
    }

    $pkgTest = Get-Command pkg-config -ErrorAction SilentlyContinue
    if ($pkgTest) {
        & pkg-config --exists mupdf 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  pkg-config --exists mupdf: OK" -ForegroundColor Green
        } else {
            Write-Host "  pkg-config --exists mupdf: FAILED (may need new shell session)" -ForegroundColor Yellow
        }
        $global:LASTEXITCODE = 0  # informational check — never fail the install step
    }

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  MuPDF Installation Complete!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Installed to: $MuPDFDir"
    Write-Host ""

} finally {
    Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue
}
