#
# Faria Toolchain Setup Script for Windows
# Ensures MSYS2 + MinGW-w64 + pkg-config are available for CGO compilation
#
# Usage: .\setup-toolchain.ps1 [-InstallDir DIR]
#

param(
    [string]$InstallDir = "$env:USERPROFILE\.faria",
    [switch]$Help
)

if ($Help) {
    Write-Host "Faria Toolchain Setup Script"
    Write-Host ""
    Write-Host "Usage: .\setup-toolchain.ps1 [OPTIONS]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -InstallDir DIR  Install to DIR (default: $env:USERPROFILE\.faria)"
    Write-Host "  -Help            Show this help message"
    Write-Host ""
    Write-Host "Installs MSYS2 + MinGW-w64 + pkg-config for CGO compilation."
    exit 0
}

$MinGWBin = "C:\msys64\mingw64\bin"
$PkgConfigDir = "C:\msys64\mingw64\lib\pkgconfig"

Write-Host "========================================" -ForegroundColor Blue
Write-Host "  Faria Toolchain Setup (MinGW-w64)" -ForegroundColor Blue
Write-Host "========================================" -ForegroundColor Blue
Write-Host ""

# ── Check if MinGW gcc is already on PATH ────────────────────────────────────
$gccCmd = Get-Command gcc -ErrorAction SilentlyContinue
if ($gccCmd) {
    $gccVer = (& gcc --version 2>&1 | Select-Object -First 1)
    if ($gccVer -match "mingw") {
        Write-Host "MinGW-w64 gcc already available: $gccVer" -ForegroundColor Green
        Write-Host ""

        # Ensure PKG_CONFIG_PATH is set for MSYS2
        New-Item -ItemType Directory -Force -Path $PkgConfigDir | Out-Null
        $existingPcp = [Environment]::GetEnvironmentVariable("PKG_CONFIG_PATH", "User")
        if (-not ($existingPcp -split ";" | Where-Object { $_ -eq $PkgConfigDir })) {
            $newPcp = if ($existingPcp) { "$existingPcp;$PkgConfigDir" } else { $PkgConfigDir }
            [Environment]::SetEnvironmentVariable("PKG_CONFIG_PATH", $newPcp, "User")
            $env:PKG_CONFIG_PATH = $newPcp
        }
        exit 0
    }
}

# ── MSYS2 already installed? ─────────────────────────────────────────────────
$msys2Exists = (Get-Command msys2 -ErrorAction SilentlyContinue) -or (Test-Path "C:\msys64")

if (-not $msys2Exists) {
    Write-Host "MSYS2 not found. Installing via winget..." -ForegroundColor Yellow
    Write-Host ""

    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if (-not $winget) {
        Write-Host "Error: winget not found." -ForegroundColor Red
        Write-Host "Install winget (App Installer) from the Microsoft Store, then re-run." -ForegroundColor Yellow
        exit 1
    }

    & winget install --id MSYS2.MSYS2 --silent --accept-source-agreements --accept-package-agreements
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error: winget install MSYS2 failed (exit code $LASTEXITCODE)." -ForegroundColor Red
        exit 1
    }

    Write-Host "MSYS2 installed." -ForegroundColor Green
    Write-Host ""
} else {
    Write-Host "MSYS2 found at C:\msys64." -ForegroundColor Green
    Write-Host ""
}

# ── Install MinGW-w64 packages via pacman ────────────────────────────────────
Write-Host "Installing MinGW-w64 packages..." -ForegroundColor Yellow

$pacman = "C:\msys64\usr\bin\pacman.exe"
if (-not (Test-Path $pacman)) {
    Write-Host "Error: pacman not found at $pacman" -ForegroundColor Red
    exit 1
}

$packages = @(
    "mingw-w64-x86_64-gcc",
    "mingw-w64-x86_64-pkg-config",
    "mingw-w64-x86_64-cmake"
)

foreach ($pkg in $packages) {
    Write-Host "  Installing $pkg..."
    & $pacman -S --noconfirm --needed $pkg
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Warning: pacman failed for $pkg (exit $LASTEXITCODE)" -ForegroundColor Yellow
    }
}

Write-Host "MinGW-w64 packages installed." -ForegroundColor Green
Write-Host ""

# ── Add MinGW bin to user PATH permanently ───────────────────────────────────
$currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
if (-not ($currentPath -split ";" | Where-Object { $_ -eq $MinGWBin })) {
    $newPath = if ($currentPath) { "$currentPath;$MinGWBin" } else { $MinGWBin }
    [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
    Write-Host "Added $MinGWBin to user PATH." -ForegroundColor Green
}

# Apply to current session
if ($env:PATH -notmatch [regex]::Escape($MinGWBin)) {
    $env:PATH = "$env:PATH;$MinGWBin"
}

# ── Ensure pkg-config dir exists and is on PKG_CONFIG_PATH ──────────────────
New-Item -ItemType Directory -Force -Path $PkgConfigDir | Out-Null

$existingPcp = [Environment]::GetEnvironmentVariable("PKG_CONFIG_PATH", "User")
if (-not ($existingPcp -split ";" | Where-Object { $_ -eq $PkgConfigDir })) {
    $newPcp = if ($existingPcp) { "$existingPcp;$PkgConfigDir" } else { $PkgConfigDir }
    [Environment]::SetEnvironmentVariable("PKG_CONFIG_PATH", $newPcp, "User")
    $env:PKG_CONFIG_PATH = $newPcp
    Write-Host "Set PKG_CONFIG_PATH to include $PkgConfigDir." -ForegroundColor Green
}

# ── Verify ───────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "Verifying toolchain..." -ForegroundColor Yellow

$gccNew = Get-Command gcc -ErrorAction SilentlyContinue
if ($gccNew) {
    $ver = (& gcc --version 2>&1 | Select-Object -First 1)
    Write-Host "  gcc: $ver" -ForegroundColor Green
} else {
    Write-Host "  gcc: not found in PATH (may need a new shell session)" -ForegroundColor Yellow
}

$pkgConfigNew = Get-Command pkg-config -ErrorAction SilentlyContinue
if ($pkgConfigNew) {
    $ver = (& pkg-config --version 2>&1)
    Write-Host "  pkg-config: $ver" -ForegroundColor Green
} else {
    Write-Host "  pkg-config: not found in PATH (may need a new shell session)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Toolchain Setup Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "MinGW-w64 bin: $MinGWBin"
Write-Host "pkg-config dir: $PkgConfigDir"
Write-Host ""
Write-Host "Note: Open a new PowerShell session for PATH changes to take full effect." -ForegroundColor Yellow
Write-Host ""
