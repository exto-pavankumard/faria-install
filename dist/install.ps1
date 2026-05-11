#
# Faria Installation Script - Single-file Installer for Windows
# AUTO-GENERATED FILE - DO NOT EDIT DIRECTLY
#
# Generated from modular source files by build/build.sh
# Source: https://github.com/exto360-inc/faria-install
#
# Usage:
#   irm https://raw.githubusercontent.com/exto360-inc/faria-install/main/dist/install.ps1 | iex
#
# Or download and run:
#   Invoke-WebRequest -Uri "..." -OutFile "install.ps1"
#   .\install.ps1 -Features idp
#   .\install.ps1 -Features chat
#   .\install.ps1 -Features all
#

# Build date: 2026-05-11T10:51:13Z
# GitHub URL: https://raw.githubusercontent.com/exto360-inc/faria-install/main

param(
    [string]$Features = "",
    [string]$InstallDir = "$env:USERPROFILE\.faria",
    [switch]$GPU,
    [switch]$WithLLM,
    [switch]$System,
    [switch]$Help
)

# ============================================================================
# Common Utilities (from scripts/_common.ps1)
# ============================================================================

# ============================================================================
# SYSTEM DETECTION
# ============================================================================

# Get system architecture
function Get-SystemArchitecture {
    return [System.Environment]::GetEnvironmentVariable("PROCESSOR_ARCHITECTURE")
}

# Check if a command exists
function Test-CommandExists {
    param([string]$Command)
    return $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
}

# ============================================================================
# DOWNLOAD HELPERS
# ============================================================================

# Download a file with progress
# Returns: $true on success, $false on failure
function Invoke-Download {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Url,
        [Parameter(Mandatory=$true)]
        [string]$Destination,
        [switch]$Silent
    )

    try {
        if ($Silent) {
            $ProgressPreference = 'SilentlyContinue'
        }
        Invoke-WebRequest -Uri $Url -OutFile $Destination -UseBasicParsing
        $ProgressPreference = 'Continue'
        return $true
    } catch {
        Write-Host "Download failed: $_" -ForegroundColor Red
        return $false
    }
}

# Download a file using BITS transfer (with fallback to Invoke-WebRequest)
function Invoke-SmartDownload {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Url,
        [Parameter(Mandatory=$true)]
        [string]$Destination
    )

    try {
        Start-BitsTransfer -Source $Url -Destination $Destination -ErrorAction Stop
        return $true
    } catch {
        # Fallback to Invoke-WebRequest
        return Invoke-Download -Url $Url -Destination $Destination
    }
}

# ============================================================================
# VERSION COMPARISON
# ============================================================================

# Compare two semantic versions
# Returns: $true if $Current >= $Minimum
function Compare-Version {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Current,
        [Parameter(Mandatory=$true)]
        [string]$Minimum
    )

    try {
        return [Version]$Current -ge [Version]$Minimum
    } catch {
        # Fallback: string comparison
        return $Current -ge $Minimum
    }
}

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

# Print a section header
function Write-Header {
    param([string]$Text)
    Write-Host "========================================" -ForegroundColor Blue
    Write-Host "  $Text" -ForegroundColor Blue
    Write-Host "========================================" -ForegroundColor Blue
    Write-Host ""
}

# Print a step header
function Write-Step {
    param(
        [int]$Step,
        [int]$Total,
        [string]$Name
    )
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Blue
    Write-Host "  Step ${Step}/${Total}: $Name" -ForegroundColor Blue
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Blue
    Write-Host ""
}

# Create a temporary directory
# Returns: path to temp directory
function New-TempDirectory {
    param([string]$Prefix = "faria")
    $TempPath = Join-Path $env:TEMP "$Prefix-$(Get-Random)"
    New-Item -ItemType Directory -Force -Path $TempPath | Out-Null
    return $TempPath
}

# Clean up a directory
function Remove-TempDirectory {
    param([string]$Path)
    if (Test-Path $Path) {
        Remove-Item -Path $Path -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Check if running in interactive mode
function Test-Interactive {
    return [Environment]::UserInteractive -and -not [Console]::IsInputRedirected
}

# Prompt for yes/no confirmation
# Returns: $true for yes, $false for no
function Confirm-Action {
    param(
        [string]$Prompt,
        [string]$Default = "n"
    )

    if (-not (Test-Interactive)) {
        # Non-interactive mode: use default
        return $Default -eq 'y' -or $Default -eq 'Y'
    }

    $response = Read-Host $Prompt
    return $response -eq 'y' -or $response -eq 'Y'
}

# Print success banner
function Write-SuccessBanner {
    param([string]$Text = "Installation Complete!")
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  $Text" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
}

# Print warning banner
function Write-WarningBanner {
    param([string]$Text)
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host "  $Text" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host ""
}

# ============================================================================
# ENVIRONMENT HELPERS
# ============================================================================

# Persist an environment variable to the user registry and apply to current session
function Set-UserEnv {
    param(
        [Parameter(Mandatory=$true)][string]$Name,
        [Parameter(Mandatory=$true)][string]$Value
    )
    [Environment]::SetEnvironmentVariable($Name, $Value, "User")
    Set-Item -Path "Env:$Name" -Value $Value -ErrorAction SilentlyContinue
}

# ============================================================================
# CHECKSUM VERIFICATION
# ============================================================================

# Verify a file's SHA-256 hash against an expected value (hex string)
# Throws on mismatch
function Invoke-ChecksumVerify {
    param(
        [Parameter(Mandatory=$true)][string]$FilePath,
        [Parameter(Mandatory=$true)][string]$ExpectedHash,
        [string]$Algorithm = "SHA256"
    )
    $actual = (Get-FileHash -Path $FilePath -Algorithm $Algorithm).Hash.ToLower()
    $expected = $ExpectedHash.ToLower().Trim()
    if ($actual -ne $expected) {
        throw "Checksum mismatch for $FilePath`n  Expected: $expected`n  Actual:   $actual"
    }
}

# ============================================================================
# MSYS2 PATH DETECTION
# ============================================================================

# Return the MinGW64 pkgconfig directory for whichever MSYS2 installation is
# active. setup-msys2@v2 may install to a non-default location (e.g. D:\a\_temp\msys64)
# instead of C:\msys64. Resolving via the pkgconf/pkg-config binary on PATH
# (which setup-msys2 adds) gives the canonical location.
function Get-MSYS2PkgConfigDir {
    $pkgCmd = Get-Command pkgconf -ErrorAction SilentlyContinue
    if (-not $pkgCmd) { $pkgCmd = Get-Command pkg-config -ErrorAction SilentlyContinue }
    if ($pkgCmd) {
        return Join-Path (Split-Path -Parent (Split-Path -Parent $pkgCmd.Source)) "lib\pkgconfig"
    }
    return "C:\msys64\mingw64\lib\pkgconfig"  # fallback for machines without MSYS2 on PATH
}

# ============================================================================
# BITS DOWNLOAD WRAPPER
# ============================================================================

# Download with BITS (resume-capable) and fall back to Invoke-WebRequest
function Start-BitsDownload {
    param(
        [Parameter(Mandatory=$true)][string]$Url,
        [Parameter(Mandatory=$true)][string]$Destination,
        [string]$Description = ""
    )
    try {
        $bitsArgs = @{ Source = $Url; Destination = $Destination; Priority = "Foreground" }
        if ($Description) { $bitsArgs.Description = $Description }
        Start-BitsTransfer @bitsArgs -ErrorAction Stop
    } catch {
        Write-Host "  BITS unavailable, falling back to WebRequest..." -ForegroundColor Yellow
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $Url -OutFile $Destination -UseBasicParsing
        $ProgressPreference = 'Continue'
    }
}


# ============================================================================
# Models Cache Helper
# ============================================================================
$script:ModelsCacheDir = $null

function Initialize-ModelsCache {
    if ($script:ModelsCacheDir -and (Test-Path $script:ModelsCacheDir)) {
        return $script:ModelsCacheDir
    }

    $script:ModelsCacheDir = New-TempDirectory -Prefix "faria-models"

    Write-Host "Downloading model export scripts from GitHub..." -ForegroundColor Yellow

    $baseUrl = "https://raw.githubusercontent.com/exto360-inc/faria-install/main/models"

    $files = @(
        "requirements-detr.txt",
        "requirements-nemotron.txt",
        "export_detr_layout_onnx.py",
        "export_nemotron_onnx.py"
    )

    foreach ($file in $files) {
        $dest = Join-Path $script:ModelsCacheDir $file
        if (-not (Invoke-Download -Url "$baseUrl/$file" -Destination $dest -Silent)) {
            Write-Host "Failed to download: $file" -ForegroundColor Red
            return $null
        }
    }

    Write-Host "Model scripts downloaded." -ForegroundColor Green
    return $script:ModelsCacheDir
}

function Remove-ModelsCache {
    if ($script:ModelsCacheDir -and (Test-Path $script:ModelsCacheDir)) {
        Remove-TempDirectory -Path $script:ModelsCacheDir
        $script:ModelsCacheDir = $null
    }
}


# ============================================================================
# Initialize-Python - from setup-python.ps1
# ============================================================================
function Initialize-Python {
    param(
        [string]$InstallDir = "$env:USERPROFILE\.faria",
        [switch]$GPU,
        [switch]$WithLLM,
        [switch]$System
    )

    
    if ($Help) {
        Write-Host "Faria Python Setup Script"
        Write-Host ""
        Write-Host "Usage: `$PythonCmd = & .\setup-python.ps1"
        Write-Host ""
        Write-Host "Ensures Python 3.12.x is available for onnxruntime compatibility."
        Write-Host "Returns the path to the Python interpreter."
        return
    }
    
    # Required Python version
    $RequiredMajor = 3
    $RequiredMinor = 12
    
    function Test-PythonVersion {
        param([string]$PythonPath)
    
        try {
            $version = & $PythonPath --version 2>&1
            if ($version -match "Python (\d+)\.(\d+)\.(\d+)") {
                $major = [int]$Matches[1]
                $minor = [int]$Matches[2]
                if ($major -eq $RequiredMajor -and $minor -eq $RequiredMinor) {
                    return $true
                }
            }
        } catch {
            return $false
        }
        return $false
    }
    
    function Find-CompatiblePython {
        # Check common Python 3.12 paths on Windows
        $candidates = @(
            "python3.12",
            "python3",
            "python",
            "$env:LOCALAPPDATA\Programs\Python\Python312\python.exe",
            "$env:ProgramFiles\Python312\python.exe",
            "$env:ProgramFiles(x86)\Python312\python.exe",
            "C:\Python312\python.exe"
        )
    
        # Also check pyenv-win paths
        $pyenvRoot = $env:PYENV_ROOT
        if (-not $pyenvRoot) {
            $pyenvRoot = "$env:USERPROFILE\.pyenv\pyenv-win"
        }
        if (Test-Path "$pyenvRoot\versions") {
            $pyenvVersions = Get-ChildItem "$pyenvRoot\versions" -Directory | Where-Object { $_.Name -match "^3\.12\." }
            foreach ($v in $pyenvVersions) {
                $candidates += "$($v.FullName)\python.exe"
            }
        }
    
        foreach ($candidate in $candidates) {
            if (Test-PythonVersion $candidate) {
                # Resolve to full path if it's a command
                try {
                    $resolved = (Get-Command $candidate -ErrorAction SilentlyContinue).Source
                    if ($resolved) { return $resolved }
                    return $candidate
                } catch {
                    if (Test-Path $candidate) { return $candidate }
                }
            }
        }
    
        return $null
    }
    
    function Install-PyenvWin {
        Write-Host "Installing pyenv-win..." -ForegroundColor Yellow
    
        # Install pyenv-win via PowerShell
        $pyenvInstaller = "https://raw.githubusercontent.com/pyenv-win/pyenv-win/master/pyenv-win/install-pyenv-win.ps1"
    
        try {
            Invoke-WebRequest -UseBasicParsing -Uri $pyenvInstaller -OutFile "./install-pyenv-win.ps1"
            & "./install-pyenv-win.ps1"
            Remove-Item "./install-pyenv-win.ps1" -Force
        } catch {
            Write-Host "Failed to install pyenv-win automatically." -ForegroundColor Red
            Write-Host ""
            Write-Host "Please install pyenv-win manually:" -ForegroundColor Yellow
            Write-Host "  1. Open PowerShell as Administrator"
            Write-Host "  2. Run: Invoke-WebRequest -UseBasicParsing -Uri `"https://raw.githubusercontent.com/pyenv-win/pyenv-win/master/pyenv-win/install-pyenv-win.ps1`" -OutFile `"./install-pyenv-win.ps1`"; &`"./install-pyenv-win.ps1`""
            Write-Host ""
            Write-Host "Or install Python 3.12 directly from: https://www.python.org/downloads/"
            throw "Installation step failed"
        }
    
        # Set up environment for current session
        $env:PYENV_ROOT = "$env:USERPROFILE\.pyenv\pyenv-win"
        $env:PATH = "$env:PYENV_ROOT\bin;$env:PYENV_ROOT\shims;$env:PATH"
    }
    
    function Setup-Pyenv {
        Write-Host "Setting up Python $RequiredMajor.$RequiredMinor via pyenv-win..." -ForegroundColor Yellow
    
        # Check if pyenv-win is installed
        $pyenvRoot = $env:PYENV_ROOT
        if (-not $pyenvRoot) {
            $pyenvRoot = "$env:USERPROFILE\.pyenv\pyenv-win"
        }
    
        $pyenvExe = "$pyenvRoot\bin\pyenv.bat"
        if (-not (Test-Path $pyenvExe)) {
            Install-PyenvWin
            $pyenvExe = "$pyenvRoot\bin\pyenv.bat"
        }
    
        if (-not (Test-Path $pyenvExe)) {
            Write-Host "Error: pyenv-win installation failed." -ForegroundColor Red
            throw "Installation step failed"
        }
    
        # Check if Python 3.12 is already installed via pyenv
        $installedVersions = & $pyenvExe versions --bare 2>$null
        $pyenv312 = $installedVersions | Where-Object { $_ -match "^3\.12\." } | Select-Object -Last 1
    
        if (-not $pyenv312) {
            Write-Host "Installing Python $RequiredMajor.$RequiredMinor via pyenv-win..." -ForegroundColor Yellow
            Write-Host "  This may take several minutes..."
    
            # Find latest 3.12.x version available
            $availableVersions = & $pyenvExe install --list 2>$null
            $latest312 = $availableVersions | Where-Object { $_ -match "^\s*3\.12\.\d+\s*$" } | ForEach-Object { $_.Trim() } | Select-Object -Last 1
    
            if (-not $latest312) {
                Write-Host "Error: Could not find Python $RequiredMajor.$RequiredMinor.x in pyenv." -ForegroundColor Red
                Write-Host "  Try running: pyenv install --list | Select-String '3.12'"
                throw "Installation step failed"
            }
    
            & $pyenvExe install $latest312
            $pyenv312 = $latest312
        }
    
        Write-Host "Using pyenv Python: $pyenv312" -ForegroundColor Green
    
        # Return the full path to the Python binary
        return "$pyenvRoot\versions\$pyenv312\python.exe"
    }
    
    # Main logic
    Write-Host "Checking Python version..." -ForegroundColor Yellow
    
    # First try to find a compatible Python
    $pythonPath = Find-CompatiblePython
    
    if ($pythonPath) {
        $version = & $pythonPath --version 2>&1
        Write-Host "Found $version at: $pythonPath" -ForegroundColor Green
    } else {
        # Check what version we have
        try {
            $currentVersion = & python --version 2>&1
            Write-Host "System Python is $currentVersion (need $RequiredMajor.$RequiredMinor.x for onnxruntime)" -ForegroundColor Yellow
        } catch {
            Write-Host "No Python found" -ForegroundColor Yellow
        }
    
        # Use pyenv-win to get the right version
        $pythonPath = Setup-Pyenv
    }
    
    if (-not $pythonPath -or -not (Test-Path $pythonPath)) {
        Write-Host "Error: Could not find or install Python $RequiredMajor.$RequiredMinor" -ForegroundColor Red
        throw "Installation step failed"
    }
    
    # Return the path
    return $pythonPath
}

# ============================================================================
# Invoke-SetupToolchain - from setup-toolchain.ps1
# ============================================================================
function Invoke-SetupToolchain {
    param(
        [string]$InstallDir = "$env:USERPROFILE\.faria",
        [switch]$GPU,
        [switch]$WithLLM,
        [switch]$System
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
        return
    }
    
    $MinGWBin = "C:\msys64\mingw64\bin"        # used only in the pacman-install fallback path
    $PkgConfigDir = "C:\msys64\mingw64\lib\pkgconfig"  # overridden dynamically when MSYS2 is on PATH
    
    if (-not (Get-Command 'Set-UserEnv' -ErrorAction SilentlyContinue)) {
        . (Join-Path $PSScriptRoot '_common.ps1')
    }
    
    Write-Host "========================================" -ForegroundColor Blue
    Write-Host "  Faria Toolchain Setup (MinGW-w64)" -ForegroundColor Blue
    Write-Host "========================================" -ForegroundColor Blue
    Write-Host ""
    
    # ── Check if MinGW gcc is already on PATH ────────────────────────────────────
    $gccCmd = Get-Command gcc -ErrorAction SilentlyContinue
    if ($gccCmd) {
        $gccVer = (& gcc --version 2>&1 | Select-Object -First 1)
        if ($gccVer -match "mingw|msys2|MSYS2") {
            Write-Host "MinGW-w64/MSYS2 gcc already available: $gccVer" -ForegroundColor Green
            Write-Host ""
    
            # Resolve the actual pkgconfig dir for this MSYS2 installation (may not be C:\msys64)
            $PkgConfigDir = Get-MSYS2PkgConfigDir
            New-Item -ItemType Directory -Force -Path $PkgConfigDir | Out-Null
            $existingPcp = [Environment]::GetEnvironmentVariable("PKG_CONFIG_PATH", "User")
            if (-not ($existingPcp -split ";" | Where-Object { $_ -eq $PkgConfigDir })) {
                $newPcp = if ($existingPcp) { "$existingPcp;$PkgConfigDir" } else { $PkgConfigDir }
                [Environment]::SetEnvironmentVariable("PKG_CONFIG_PATH", $newPcp, "User")
                $env:PKG_CONFIG_PATH = $newPcp
                Write-Host "Set PKG_CONFIG_PATH to include $PkgConfigDir." -ForegroundColor Green
            }
            return
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
            throw "Installation step failed"
        }
    
        & winget install --id MSYS2.MSYS2 --silent --accept-source-agreements --accept-package-agreements
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Error: winget install MSYS2 failed (exit code $LASTEXITCODE)." -ForegroundColor Red
            throw "Installation step failed"
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
        throw "Installation step failed"
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
}

# ============================================================================
# Invoke-InstallOpenCV - from install-opencv.ps1
# ============================================================================
function Invoke-InstallOpenCV {
    param(
        [string]$InstallDir = "$env:USERPROFILE\.faria",
        [switch]$GPU,
        [switch]$WithLLM,
        [switch]$System
    )

    
    if (-not (Get-Command 'Set-UserEnv' -ErrorAction SilentlyContinue)) {
        . (Join-Path $PSScriptRoot '_common.ps1')
    }
    
    if ($Help) {
        Write-Host "Faria OpenCV Installation Script"
        Write-Host ""
        Write-Host "Usage: .\install-opencv.ps1 [OPTIONS]"
        Write-Host ""
        Write-Host "Options:"
        Write-Host "  -InstallDir DIR  Install to DIR (default: $env:USERPROFILE\.faria)"
        Write-Host "  -Force           Reinstall even if already present"
        Write-Host "  -Help            Show this help message"
        return
    }
    
    $OpenCVVersion = "4.12.0"
    $OpenCVDir     = "$InstallDir\lib\opencv"
    $PkgConfigDir  = Get-MSYS2PkgConfigDir
    
    # Asset hosted in faria-install GitHub Releases.
    # Override FARIA_RELEASE_REPO env var to download from a fork (e.g. for CI on a fork).
    $ReleaseRepo   = if ($env:FARIA_RELEASE_REPO) { $env:FARIA_RELEASE_REPO } else { "exto360-inc/faria-install" }
    $OpenCVAsset   = "opencv-$OpenCVVersion-windows-x86_64.zip"
    $OpenCVUrl     = "https://github.com/$ReleaseRepo/releases/download/opencv-$OpenCVVersion/$OpenCVAsset"
    $ChecksumsUrl  = "https://github.com/$ReleaseRepo/releases/download/opencv-$OpenCVVersion/checksums.txt"
    
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
        throw "Installation step failed"
    }
    
    # ── Already installed? ────────────────────────────────────────────────────────
    $existingDll = Get-ChildItem -Path "$OpenCVDir\bin" -Filter "libopencv_core*.dll" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($existingDll -and -not $Force) {
        Write-Host "OpenCV $OpenCVVersion already installed at $OpenCVDir" -ForegroundColor Green
        return
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
        $rootDirs  = @(Get-ChildItem -Path $ExtractDir -Directory)
        $rootFiles = @(Get-ChildItem -Path $ExtractDir -File)
        if ($rootDirs.Count -eq 1 -and $rootFiles.Count -eq 0) {
            # Single wrapper directory (e.g. opencv-4.12.0/) — promote its contents
            Move-Item -Path $rootDirs[0].FullName -Destination $OpenCVDir -Force
        } else {
            # Flat archive — include/, lib/, bin/ directly at root
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
        $dll = Get-ChildItem -Path "$OpenCVDir\bin" -Filter "libopencv_core*.dll" -ErrorAction SilentlyContinue | Select-Object -First 1
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
            $global:LASTEXITCODE = 0  # informational check — never fail the install step
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
}

# ============================================================================
# Invoke-InstallTesseract - from install-tesseract.ps1
# ============================================================================
function Invoke-InstallTesseract {
    param(
        [string]$InstallDir = "$env:USERPROFILE\.faria",
        [switch]$GPU,
        [switch]$WithLLM,
        [switch]$System
    )

    
    # Configuration
    # UB-Mannheim releases embed the build date in the version string (e.g. 5.4.0.20240606).
    $TesseractVersion = "5.4.0.20240606"
    $TesseractDir     = "$InstallDir\tesseract"
    
    if (-not (Get-Command 'Set-UserEnv' -ErrorAction SilentlyContinue)) {
        . (Join-Path $PSScriptRoot '_common.ps1')
    }
    
    $PkgConfigDir = Get-MSYS2PkgConfigDir
    
    if ($Help) {
        Write-Host "Faria Tesseract OCR Installation Script"
        Write-Host ""
        Write-Host "Usage: .\install-tesseract.ps1 [OPTIONS]"
        Write-Host ""
        Write-Host "Options:"
        Write-Host "  -InstallDir DIR  Install to DIR (default: $env:USERPROFILE\.faria)"
        Write-Host "  -Force           Reinstall even if already present"
        Write-Host "  -Help            Show this help message"
        return
    }
    
    Write-Host "========================================" -ForegroundColor Blue
    Write-Host "  Faria Tesseract OCR Installation" -ForegroundColor Blue
    Write-Host "========================================" -ForegroundColor Blue
    Write-Host ""
    
    $Arch = [System.Environment]::GetEnvironmentVariable("PROCESSOR_ARCHITECTURE")
    Write-Host "Architecture: $Arch"
    Write-Host "Install directory: $TesseractDir"
    Write-Host ""
    
    if ($Arch -ne "AMD64") {
        Write-Host "Error: Only x86_64 (AMD64) Windows is supported." -ForegroundColor Red
        throw "Installation step failed"
    }
    
    # ── Already installed? ────────────────────────────────────────────────────────
    $tessExe = "$TesseractDir\tesseract.exe"
    if ((Test-Path $tessExe) -and -not $Force) {
        $ver = (& $tessExe --version 2>&1 | Select-Object -First 1)
        Write-Host "Tesseract already installed: $ver" -ForegroundColor Green
        return
    }
    
    # ── Helper: register .pc files with MSYS2 pkg-config ─────────────────────────
    function Register-TesseractPkgConfig {
        param([string]$SrcPkgConfigDir)
        New-Item -ItemType Directory -Force -Path $PkgConfigDir | Out-Null
        foreach ($pc in @("tesseract.pc", "lept.pc")) {
            $src = "$SrcPkgConfigDir\$pc"
            if (Test-Path $src) {
                $dst = "$PkgConfigDir\$pc"
                # Skip when MSYS2 source dir IS the target dir (dynamic path detection resolves to same location)
                if ([System.IO.Path]::GetFullPath($src).ToLower() -eq [System.IO.Path]::GetFullPath($dst).ToLower()) {
                    Write-Host "  $pc already in pkgconfig dir (source = destination)." -ForegroundColor Green
                    continue
                }
                Copy-Item $src $dst -Force
                Write-Host "  $pc registered in MSYS2 pkgconfig dir." -ForegroundColor Green
            }
        }
    }
    
    # ── PRIMARY: MSYS2/MinGW64 Tesseract ─────────────────────────────────────────
    # When msys2/setup-msys2@v2 pre-installs mingw-w64-x86_64-tesseract-ocr the
    # UB-Mannheim NSIS installer (which hangs in headless CI) is never needed.
    $msys2Base    = "C:\msys64\mingw64"
    $msys2TessExe = "$msys2Base\bin\tesseract.exe"
    
    # Also search PATH for tesseract (handles non-default MSYS2 install paths).
    # setup-msys2@v2 adds the MSYS2 bin dir to PATH, so Get-Command is reliable.
    if (-not (Test-Path $msys2TessExe)) {
        $tessCmd = Get-Command tesseract -ErrorAction SilentlyContinue
        if ($tessCmd -and ($tessCmd.Source -match "mingw64|msys64")) {
            $msys2TessExe = $tessCmd.Source
            $msys2Base    = Split-Path -Parent (Split-Path -Parent $tessCmd.Source)
            Write-Host "MSYS2 Tesseract found on PATH: $msys2TessExe" -ForegroundColor Yellow
        }
    }
    
    if (Test-Path $msys2TessExe) {
        Write-Host "MSYS2 Tesseract detected — populating $TesseractDir from MSYS2..." -ForegroundColor Yellow
        Write-Host ""
    
        New-Item -ItemType Directory -Force -Path $TesseractDir | Out-Null
    
        # tesseract.exe
        Copy-Item $msys2TessExe "$TesseractDir\tesseract.exe" -Force
        Write-Host "  tesseract.exe: copied" -ForegroundColor Green
    
        # tessdata — copy .traineddata files
        $msys2Tessdata = "$msys2Base\share\tessdata"
        $TessdataPath  = "$TesseractDir\tessdata"
        if (Test-Path $msys2Tessdata) {
            New-Item -ItemType Directory -Force -Path $TessdataPath | Out-Null
            Get-ChildItem $msys2Tessdata -Filter "*.traineddata" |
                Copy-Item -Destination $TessdataPath -Force
            Write-Host "  tessdata: copied" -ForegroundColor Green
        }
    
        # Headers: tesseract/ and leptonica/
        New-Item -ItemType Directory -Force -Path "$TesseractDir\include" | Out-Null
        foreach ($hdr in @("tesseract", "leptonica")) {
            $src = "$msys2Base\include\$hdr"
            if (Test-Path $src) {
                Copy-Item $src "$TesseractDir\include\$hdr" -Recurse -Force
                Write-Host "  include/${hdr}: copied" -ForegroundColor Green
            }
        }
    
        # Import libs needed for CGO linking
        New-Item -ItemType Directory -Force -Path "$TesseractDir\lib" | Out-Null
        foreach ($pattern in @("libtesseract*", "liblept*")) {
            Get-ChildItem "$msys2Base\lib" -Filter $pattern -ErrorAction SilentlyContinue |
                Copy-Item -Destination "$TesseractDir\lib\" -Force
        }
        Write-Host "  lib: import libs copied" -ForegroundColor Green
    
        # pkg-config .pc files — copy to $TesseractDir\lib\pkgconfig AND MSYS2 dir
        $msys2PkgConfig = "$msys2Base\lib\pkgconfig"
        New-Item -ItemType Directory -Force -Path "$TesseractDir\lib\pkgconfig" | Out-Null
        foreach ($pc in @("tesseract.pc", "lept.pc")) {
            $src = "$msys2PkgConfig\$pc"
            if (Test-Path $src) {
                Copy-Item $src "$TesseractDir\lib\pkgconfig\$pc" -Force
            }
        }
        Register-TesseractPkgConfig -SrcPkgConfigDir $msys2PkgConfig
    
        # Set TESSDATA_PREFIX
        Set-UserEnv -Name "TESSDATA_PREFIX" -Value $TessdataPath
        Write-Host "TESSDATA_PREFIX set to: $TessdataPath" -ForegroundColor Green
        Write-Host ""
    
        # Verify
        Write-Host "Verifying installation..." -ForegroundColor Yellow
        $ver = (& "$TesseractDir\tesseract.exe" --version 2>&1 | Select-Object -First 1)
        Write-Host "  Tesseract: $ver" -ForegroundColor Green
    
        if (Test-Path "$TesseractDir\include\leptonica") {
            Write-Host "  Leptonica headers: OK" -ForegroundColor Green
        }
    
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Green
        Write-Host "  Tesseract Installation Complete!" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "Source: MSYS2 ($msys2Base)"
        Write-Host "Installed to: $TesseractDir"
        Write-Host "TESSDATA_PREFIX: $TessdataPath"
        Write-Host ""
        return
    }
    
    # ── FALLBACK: UB-Mannheim NSIS installer ─────────────────────────────────────
    Write-Host "MSYS2 not found — using UB-Mannheim NSIS installer..." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Tesseract version: $TesseractVersion"
    
    $TesseractAsset = "tesseract-ocr-w64-setup-$TesseractVersion.exe"
    $TesseractUrl   = "https://github.com/UB-Mannheim/tesseract/releases/download/v$TesseractVersion/$TesseractAsset"
    Write-Host "Installer: $TesseractAsset"
    Write-Host ""
    
    $TempDir = Join-Path $env:TEMP "faria-tesseract-$(Get-Random)"
    New-Item -ItemType Directory -Force -Path $TempDir | Out-Null
    
    try {
        # ── Download installer ────────────────────────────────────────────────────
        Write-Host "Downloading Tesseract installer..." -ForegroundColor Yellow
        Write-Host "  URL: $TesseractUrl"
        $InstallerPath = Join-Path $TempDir $TesseractAsset
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $TesseractUrl -OutFile $InstallerPath -UseBasicParsing
        $ProgressPreference = 'Continue'
        Write-Host "  Download complete." -ForegroundColor Green
        Write-Host ""
    
        # ── Silent NSIS install ───────────────────────────────────────────────────
        # /S = silent mode, /D = destination (must be last arg, no quotes around path)
        Write-Host "Running silent installer to $TesseractDir..." -ForegroundColor Yellow
        $proc = Start-Process -FilePath $InstallerPath `
                              -ArgumentList @("/S", "/D=$TesseractDir") `
                              -Wait -NoNewWindow -PassThru
        if ($proc.ExitCode -ne 0) {
            throw "Installer exited with code $($proc.ExitCode)"
        }
        Write-Host "  Installer finished." -ForegroundColor Green
        Write-Host ""
    
        # ── Set TESSDATA_PREFIX ───────────────────────────────────────────────────
        $TessdataPath = "$TesseractDir\tessdata"
        Set-UserEnv -Name "TESSDATA_PREFIX" -Value $TessdataPath
        Write-Host "TESSDATA_PREFIX set to: $TessdataPath" -ForegroundColor Green
        Write-Host ""
    
        # ── Register pkg-config .pc files ─────────────────────────────────────────
        Register-TesseractPkgConfig -SrcPkgConfigDir "$TesseractDir\lib\pkgconfig"
    
        # ── Verify ────────────────────────────────────────────────────────────────
        Write-Host "Verifying installation..." -ForegroundColor Yellow
    
        if (Test-Path $tessExe) {
            $ver = (& $tessExe --version 2>&1 | Select-Object -First 1)
            Write-Host "  Tesseract: $ver" -ForegroundColor Green
        } else {
            Write-Host "  tesseract.exe: NOT FOUND at $tessExe" -ForegroundColor Red
            throw "Installation step failed"
        }
    
        if (Test-Path "$TesseractDir\include\leptonica") {
            Write-Host "  Leptonica headers: OK" -ForegroundColor Green
        } else {
            Write-Host "  Leptonica headers: not found (CGO may not work)" -ForegroundColor Yellow
        }
    
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Green
        Write-Host "  Tesseract Installation Complete!" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "Installed to: $TesseractDir"
        Write-Host "TESSDATA_PREFIX: $TessdataPath"
        Write-Host ""
    
    } finally {
        Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# ============================================================================
# Invoke-InstallMuPDF - from install-mupdf.ps1
# ============================================================================
function Invoke-InstallMuPDF {
    param(
        [string]$InstallDir = "$env:USERPROFILE\.faria",
        [switch]$GPU,
        [switch]$WithLLM,
        [switch]$System
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
        return
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
        throw "Installation step failed"
    }
    
    # ── Already installed? ────────────────────────────────────────────────────────
    $libPath = "$MuPDFDir\lib\libmupdf.a"
    if ((Test-Path $libPath) -and -not $Force) {
        Write-Host "MuPDF $MuPDFVersion already installed at $MuPDFDir" -ForegroundColor Green
        return
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
            $PcContent = (Get-Content $PcDest) -replace 'prefix=.*', "prefix=$prefix"
            # pkgconf v2+ requires a Description field; inject it if the tarball omitted it
            if (-not ($PcContent | Where-Object { $_ -match '^Description:' })) {
                $PcContent = @("Description: MuPDF static library for CGO PDF processing") + $PcContent
            }
            $PcContent | Set-Content $PcDest
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
}

# ============================================================================
# Invoke-InstallOnnxRuntime - from install-onnxruntime.ps1
# ============================================================================
function Invoke-InstallOnnxRuntime {
    param(
        [string]$InstallDir = "$env:USERPROFILE\.faria",
        [switch]$GPU,
        [switch]$WithLLM,
        [switch]$System
    )

    
    $OnnxRuntimeVersion = "1.22.0"
    
    if (-not (Get-Command 'Set-UserEnv' -ErrorAction SilentlyContinue)) {
        . (Join-Path $PSScriptRoot '_common.ps1')
    }
    
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
        return
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
            throw "Installation step failed"
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
            throw "Installation step failed"
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
        return
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
            throw "Installation step failed"
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
            throw "Installation step failed"
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
}

# ============================================================================
# Invoke-InstallModels - from install-models.ps1
# ============================================================================
function Invoke-InstallModels {
    param(
        [string]$InstallDir = "$env:USERPROFILE\.faria",
        [switch]$GPU,
        [switch]$WithLLM,
        [switch]$System
    )

    
    if ($Help) {
        Write-Host "Faria ML Models Installation Script"
        Write-Host ""
        Write-Host "Usage: .\install-models.ps1 [OPTIONS]"
        Write-Host ""
        Write-Host "Options:"
        Write-Host "  -InstallDir DIR   Install to DIR (default: $env:USERPROFILE\.faria)"
        Write-Host "  -System           Download pre-exported ONNX from HuggingFace (skip Python)"
        Write-Host "  -SkipDETR         Skip DETR model installation"
        Write-Host "  -SkipNemotron     Skip Nemotron model installation"
        Write-Host "  -KeepVenv         Keep Python virtual environment after installation"
        Write-Host "  -Help             Show this help message"
        return
    }
    
    if (-not (Get-Command 'Set-UserEnv' -ErrorAction SilentlyContinue)) {
        . (Join-Path $PSScriptRoot '_common.ps1')
    }
    
    Write-Host "========================================" -ForegroundColor Blue
    Write-Host "  Faria ML Models Installation" -ForegroundColor Blue
    Write-Host "========================================" -ForegroundColor Blue
    Write-Host ""
    
    
    $ModelsDir        = "$InstallDir\models"
    $DETRModelPath    = "$ModelsDir\detr_layout_detection.onnx"
    $NemotronModelPath = "$ModelsDir\nemotron_table_structure.onnx"
    $CLIPModelPath    = "$ModelsDir\clip_vision.onnx"
    
    $HFBase    = "https://huggingface.co/pavan-synkrato360/faria-models/resolve/main"
    $CLIPUrl   = "https://huggingface.co/Qdrant/clip-ViT-B-32-vision/resolve/main/model.onnx"
    
    Write-Host "Install directory: $ModelsDir"
    Write-Host "Mode: $(if ($System) { 'system (HuggingFace download)' } else { 'local Python export' })"
    Write-Host ""
    
    New-Item -ItemType Directory -Force -Path $ModelsDir | Out-Null
    
    # ============================================================================
    # System mode: download pre-exported ONNX directly from HuggingFace
    # ============================================================================
    if ($System) {
        if (-not $SkipDETR) {
            if (Test-Path $DETRModelPath) {
                Write-Host "DETR model already exists — skipping." -ForegroundColor Yellow
            } else {
                Write-Host "Downloading DETR model..." -ForegroundColor Yellow
                Start-BitsDownload -Url "$HFBase/detr_layout_detection.onnx" `
                                   -Destination $DETRModelPath `
                                   -Description "DETR layout detection model"
                Write-Host "  DETR downloaded." -ForegroundColor Green
            }
        }
    
        if (-not $SkipNemotron) {
            if (Test-Path $NemotronModelPath) {
                Write-Host "Nemotron model already exists — skipping." -ForegroundColor Yellow
            } else {
                Write-Host "Downloading Nemotron model..." -ForegroundColor Yellow
                Start-BitsDownload -Url "$HFBase/nemotron_table_structure.onnx" `
                                   -Destination $NemotronModelPath `
                                   -Description "Nemotron table structure model"
                Write-Host "  Nemotron downloaded." -ForegroundColor Green
            }
        }
    } else {
        # ============================================================================
        # Local Python export path
        # ============================================================================
        $PythonCmd = & "Initialize-Python"
    
        if (-not $PythonCmd -or -not (Get-Command $PythonCmd -ErrorAction SilentlyContinue)) {
            Write-Host "Error: Python 3.12 setup failed." -ForegroundColor Red
            throw "Installation step failed"
        }
    
        if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
            Write-Host "Error: Git not found. Please install Git." -ForegroundColor Red
            throw "Installation step failed"
        }
        $GitVersion = (git --version) -replace 'git version ', ''
        Write-Host "Git: $GitVersion" -ForegroundColor Green
    
        if (-not $SkipNemotron) {
            try {
                $null = & git lfs version 2>&1
                Write-Host "Git LFS: installed" -ForegroundColor Green
            } catch {
                Write-Host "Error: Git LFS not found." -ForegroundColor Red
                Write-Host "Install from https://git-lfs.github.com/ then run: git lfs install"
                throw "Installation step failed"
            }
        }
    
        $WorkDir = Join-Path $env:TEMP "faria-models-install-$(Get-Random)"
        New-Item -ItemType Directory -Force -Path $WorkDir | Out-Null
        $VenvDir = Join-Path $WorkDir "venv"
    
        try {
            Write-Host "Creating Python virtual environment..." -ForegroundColor Yellow
            & $PythonCmd -m venv $VenvDir
    
            $ActivateScript = Join-Path $VenvDir "Scripts\Activate.ps1"
            . $ActivateScript
            & pip install --upgrade pip -q
    
            # ── DETR ──────────────────────────────────────────────────────────────
            if (-not $SkipDETR) {
                Write-Host ""
                Write-Host "Installing DETR model..." -ForegroundColor Blue
                Write-Host ""
    
                if (Test-Path $DETRModelPath) {
                    Write-Host "DETR model already exists — skipping." -ForegroundColor Yellow
                } else {
                    & pip install -r "$RepoDir\models\requirements-detr.txt" -q
                    Write-Host "Exporting DETR model to ONNX..." -ForegroundColor Yellow
    
                    $DETRExportScript = Join-Path $RepoDir "models\export_detr_layout_onnx.py"
                    if (-not (Test-Path $DETRExportScript)) {
                        Write-Host "Error: $DETRExportScript not found." -ForegroundColor Red
                        throw "Installation step failed"
                    }
                    Push-Location $WorkDir
                    & python $DETRExportScript --output $DETRModelPath
                    Pop-Location
    
                    if (-not (Test-Path $DETRModelPath)) {
                        Write-Host "Error: DETR ONNX not produced." -ForegroundColor Red
                        throw "Installation step failed"
                    }
                    $sz = [math]::Round((Get-Item $DETRModelPath).Length / 1MB, 1)
                    Write-Host "  DETR installed: $DETRModelPath ($sz MB)" -ForegroundColor Green
                }
            }
    
            # ── Nemotron ──────────────────────────────────────────────────────────
            if (-not $SkipNemotron) {
                Write-Host ""
                Write-Host "Installing Nemotron model..." -ForegroundColor Blue
                Write-Host ""
    
                if (Test-Path $NemotronModelPath) {
                    Write-Host "Nemotron model already exists — skipping." -ForegroundColor Yellow
                } else {
                    Write-Host "Cloning Nemotron repository from HuggingFace..." -ForegroundColor Yellow
                    $NemotronRepo = Join-Path $WorkDir "nemotron-table-structure-v1"
                    Push-Location $WorkDir
                    & git lfs install
                    & git clone https://huggingface.co/nvidia/nemotron-table-structure-v1 $NemotronRepo
    
                    Write-Host "Installing Nemotron package..." -ForegroundColor Yellow
                    Push-Location $NemotronRepo
                    & pip install -r "$RepoDir\models\requirements-nemotron.txt" -q
                    & pip install -e . -q
                    Pop-Location
    
                    Write-Host "Exporting Nemotron model to ONNX..." -ForegroundColor Yellow
                    $NemotronExportScript = Join-Path $RepoDir "models\export_nemotron_onnx.py"
                    if (-not (Test-Path $NemotronExportScript)) {
                        Write-Host "Error: $NemotronExportScript not found." -ForegroundColor Red
                        throw "Installation step failed"
                    }
                    & python $NemotronExportScript --output $NemotronModelPath
                    Pop-Location
    
                    if (-not (Test-Path $NemotronModelPath)) {
                        Write-Host "Error: Nemotron ONNX not produced." -ForegroundColor Red
                        throw "Installation step failed"
                    }
                    $sz = [math]::Round((Get-Item $NemotronModelPath).Length / 1MB, 1)
                    Write-Host "  Nemotron installed: $NemotronModelPath ($sz MB)" -ForegroundColor Green
                }
            }
    
            deactivate
    
        } finally {
            if (-not $KeepVenv -and (Test-Path $WorkDir)) {
                Remove-Item -Path $WorkDir -Recurse -Force -ErrorAction SilentlyContinue
            } elseif ($KeepVenv) {
                Write-Host "Keeping virtual environment at: $VenvDir" -ForegroundColor Yellow
            }
        }
    }
    
    # ============================================================================
    # CLIP: always downloaded directly, never exported locally
    # ============================================================================
    if (Test-Path $CLIPModelPath) {
        Write-Host "CLIP model already exists — skipping." -ForegroundColor Yellow
    } else {
        Write-Host ""
        Write-Host "Downloading CLIP model..." -ForegroundColor Yellow
        Start-BitsDownload -Url $CLIPUrl -Destination $CLIPModelPath -Description "CLIP vision model"
        Write-Host "  CLIP downloaded." -ForegroundColor Green
    }
    
    # ============================================================================
    # Verify
    # ============================================================================
    Write-Host ""
    Write-Host "Verifying installation..." -ForegroundColor Yellow
    
    $allOk = $true
    
    foreach ($entry in @(
        @{ Path = $DETRModelPath;     Name = "DETR";     Skip = $SkipDETR },
        @{ Path = $NemotronModelPath; Name = "Nemotron";  Skip = $SkipNemotron },
        @{ Path = $CLIPModelPath;     Name = "CLIP";      Skip = $false }
    )) {
        if ($entry.Skip) {
            Write-Host "  $($entry.Name): skipped" -ForegroundColor Yellow
        } elseif (Test-Path $entry.Path) {
            $sz = [math]::Round((Get-Item $entry.Path).Length / 1MB, 1)
            Write-Host "  $($entry.Name): OK ($sz MB)" -ForegroundColor Green
        } else {
            Write-Host "  $($entry.Name): FAILED" -ForegroundColor Red
            $allOk = $false
        }
    }
    
    if (-not $allOk) { throw "Installation step failed" }
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  Models Installation Complete!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Installed models:"
    foreach ($f in @($DETRModelPath, $NemotronModelPath, $CLIPModelPath)) {
        if (Test-Path $f) { Write-Host "  $f" }
    }
    Write-Host ""
}

# ============================================================================
# Invoke-InstallSLM - from install-slm.ps1
# ============================================================================
function Invoke-InstallSLM {
    param(
        [string]$InstallDir = "$env:USERPROFILE\.faria",
        [switch]$GPU,
        [switch]$WithLLM,
        [switch]$System
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
        return
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
            throw "Installation step failed"
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
            throw "Installation step failed"
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
            throw "Installation step failed"
        }
    
        if (Test-Path $ModelPath) {
            $ModelSize = (Get-Item $ModelPath).Length / 1MB
            Write-Host "  Model: OK ($([math]::Round($ModelSize, 1)) MB)" -ForegroundColor Green
        } else {
            Write-Host "  Model: FAILED" -ForegroundColor Red
            throw "Installation step failed"
        }
    
        # Print success message and instructions
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Green
        Write-Host "  Installation Complete!" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "Installed files:"
        Write-Host "  $InstallDir\bin\llama-cli.exe"
        Write-Host "  $InstallDir\models\$QwenModel"
        Write-Host ""
        Write-Host "Configuration Options:" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Option 1: Environment variables (recommended)"
        Write-Host "  Run these commands in PowerShell (or add to your profile):"
        Write-Host ""
        Write-Host "    `$env:FARIA_LLAMA_CLI_PATH = `"$InstallDir\bin\llama-cli.exe`""
        Write-Host "    `$env:FARIA_SLM_MODEL_PATH = `"$InstallDir\models\$QwenModel`""
        Write-Host ""
        Write-Host "  Or set them permanently:"
        Write-Host "    [Environment]::SetEnvironmentVariable('FARIA_LLAMA_CLI_PATH', '$InstallDir\bin\llama-cli.exe', 'User')"
        Write-Host "    [Environment]::SetEnvironmentVariable('FARIA_SLM_MODEL_PATH', '$InstallDir\models\$QwenModel', 'User')"
        Write-Host ""
        Write-Host "Option 2: Auto-detection"
        Write-Host "  Faria will automatically detect files in $env:USERPROFILE\.faria\ (no action needed)"
        Write-Host ""
        Write-Host "Option 3: Manual configuration in code"
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
}

# ============================================================================
# Invoke-Verify - from verify.ps1
# ============================================================================
function Invoke-Verify {
    param(
        [string]$InstallDir = "$env:USERPROFILE\.faria",
        [switch]$GPU,
        [switch]$WithLLM,
        [switch]$System
    )

    
    if ($Help) {
        Write-Host "Faria Installation Verification Script"
        Write-Host ""
        Write-Host "Usage: .\verify.ps1 [OPTIONS]"
        Write-Host ""
        Write-Host "Options:"
        Write-Host "  -InstallDir DIR  Check installation in DIR (default: $env:USERPROFILE\.faria)"
        Write-Host "  -Help            Show this help message"
        return
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
    # Check IDP Dependencies (OpenCV, Tesseract, Leptonica, MuPDF)
    # ============================================================================
    Write-Host "IDP Dependencies:" -ForegroundColor Blue
    
    # Check OpenCV
    $OpenCVDir = "$InstallDir\lib\opencv"
    $OpenCVFound = $false
    $OpenCVPath = ""
    
    # Check in install directory — MinGW builds produce libopencv_core*.dll (not opencv_world*.dll)
    $OpenCVDll = Get-ChildItem -Path "$OpenCVDir" -Recurse -Filter "libopencv_core*.dll" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($OpenCVDll) {
        $OpenCVFound = $true
        $OpenCVPath = $OpenCVDll.FullName
    }
    
    # Check via environment variable
    if (-not $OpenCVFound -and $env:OPENCV_DIR) {
        $OpenCVDll = Get-ChildItem -Path "$env:OPENCV_DIR" -Recurse -Filter "libopencv_core*.dll" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($OpenCVDll) {
            $OpenCVFound = $true
            $OpenCVPath = $OpenCVDll.FullName
        }
    }
    
    if ($OpenCVFound) {
        Write-Host "  [OK] OpenCV: Found" -ForegroundColor Green
        Write-Host "     $OpenCVPath"
    } else {
        Write-Host "  [!] OpenCV: Not found (needed for IDP)" -ForegroundColor Yellow
        Write-Host "     Install: choco install opencv"
    }
    
    # Check Tesseract
    $TesseractCmd = Get-Command tesseract -ErrorAction SilentlyContinue
    
    if ($TesseractCmd) {
        $TesseractVersion = (& tesseract --version 2>&1 | Select-Object -First 1) -replace 'tesseract ', ''
        Write-Host "  [OK] Tesseract: $TesseractVersion" -ForegroundColor Green
        Write-Host "     $($TesseractCmd.Source)"
    } else {
        Write-Host "  [!] Tesseract: Not found (needed for IDP)" -ForegroundColor Yellow
        Write-Host "     Install: https://github.com/UB-Mannheim/tesseract/wiki"
    }
    
    # Check Leptonica (bundled with Tesseract on Windows)
    if ($TesseractCmd) {
        Write-Host "  [OK] Leptonica: Included with Tesseract" -ForegroundColor Green
    } else {
        Write-Host "  [!] Leptonica: Not found (bundled with Tesseract)" -ForegroundColor Yellow
    }
    
    # Check MuPDF
    $MuToolPath = "$InstallDir\bin\mutool.exe"
    $MuToolCmd = Get-Command mutool -ErrorAction SilentlyContinue
    $MuPDFFound = $false
    $MuPDFPath = ""
    
    if (Test-Path $MuToolPath) {
        $MuPDFFound = $true
        $MuPDFPath = $MuToolPath
    } elseif ($MuToolCmd) {
        $MuPDFFound = $true
        $MuPDFPath = $MuToolCmd.Source
    }
    
    if ($MuPDFFound) {
        try {
            $MuPDFVersion = (& $MuPDFPath -v 2>&1 | Select-Object -First 1)
            Write-Host "  [OK] MuPDF: $MuPDFVersion" -ForegroundColor Green
        } catch {
            Write-Host "  [OK] MuPDF: Found" -ForegroundColor Green
        }
        Write-Host "     $MuPDFPath"
    } else {
        Write-Host "  [!] MuPDF: Not found (needed for IDP)" -ForegroundColor Yellow
        Write-Host "     Install: choco install mupdf"
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
        Write-Host "  .\install.ps1 -Features idp"
        Write-Host ""
        throw "Installation step failed"
    }
    Write-Host ""
}

# ============================================================================
# Invoke-InstallIDP - from install-idp.ps1
# ============================================================================
function Invoke-InstallIDP {
    param(
        [string]$InstallDir = "$env:USERPROFILE\.faria",
        [switch]$GPU,
        [switch]$WithLLM,
        [switch]$System
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
        return
    }
    
    
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
        & "Invoke-SetupToolchain" -InstallDir $InstallDir
        if ($LASTEXITCODE -ne 0 -and $null -ne $LASTEXITCODE) { throw "exit code $LASTEXITCODE" }
    }
    
    # Step 1: OpenCV
    Invoke-IDPStep -Name "Installing OpenCV" -Action {
        & "Invoke-InstallOpenCV" -InstallDir $InstallDir
        if ($LASTEXITCODE -ne 0 -and $null -ne $LASTEXITCODE) { throw "exit code $LASTEXITCODE" }
    }
    
    # Step 2: Tesseract (includes Leptonica)
    Invoke-IDPStep -Name "Installing Tesseract OCR" -Action {
        & "Invoke-InstallTesseract" -InstallDir $InstallDir
        if ($LASTEXITCODE -ne 0 -and $null -ne $LASTEXITCODE) { throw "exit code $LASTEXITCODE" }
    }
    
    # Step 3: MuPDF
    Invoke-IDPStep -Name "Installing MuPDF" -Action {
        & "Invoke-InstallMuPDF" -InstallDir $InstallDir
        if ($LASTEXITCODE -ne 0 -and $null -ne $LASTEXITCODE) { throw "exit code $LASTEXITCODE" }
    }
    
    # Step 4: ONNX Runtime
    Invoke-IDPStep -Name "Installing ONNX Runtime" -Action {
        $onnxArgs = @{ InstallDir = $InstallDir }
        if ($GPU) { $onnxArgs.GPU = $true }
        & "Invoke-InstallOnnxRuntime" @onnxArgs
        if ($LASTEXITCODE -ne 0 -and $null -ne $LASTEXITCODE) { throw "exit code $LASTEXITCODE" }
    }
    
    # Step 5: ML Models (DETR + Nemotron + CLIP)
    Invoke-IDPStep -Name "Installing ML Models" -Action {
        $modelArgs = @{ InstallDir = $InstallDir }
        if ($System) { $modelArgs.System = $true }
        & "Invoke-InstallModels" @modelArgs
        if ($LASTEXITCODE -ne 0 -and $null -ne $LASTEXITCODE) { throw "exit code $LASTEXITCODE" }
    }
    
    # Step 6 (optional): LLM for IDP
    if ($WithLLM) {
        Invoke-IDPStep -Name "Installing LLM for IDP" -Action {
            & "Invoke-InstallSLM" -InstallDir $InstallDir
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
    
    if ($script:InstallFailed) { throw "Installation step failed" }
}

# ============================================================================
# Invoke-InstallChat - from install-chat.ps1
# ============================================================================
function Invoke-InstallChat {
    param(
        [string]$InstallDir = "$env:USERPROFILE\.faria",
        [switch]$GPU,
        [switch]$WithLLM,
        [switch]$System
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
        return
    }
    
    # Get script directory
    
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
        & "Invoke-InstallSLM" -InstallDir $InstallDir
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
        throw "Installation step failed"
    }
}

# ============================================================================
# Main Orchestrator
# ============================================================================


# Handle help
if ($Help) {
    Write-Host "Faria Installation Script"
    Write-Host ""
    Write-Host "Usage: irm <url> | iex  # or  .\install.ps1 [OPTIONS]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -Features LIST    Comma-separated list: idp, chat, all"
    Write-Host "  -InstallDir DIR   Install to DIR (default: $env:USERPROFILE\.faria)"
    Write-Host "  -GPU              Enable GPU support (CUDA)"
    Write-Host "  -WithLLM          Install LLM support for IDP"
    Write-Host "  -System           Download pre-exported ONNX models (skip Python)"
    Write-Host "  -Help             Show this help message"
    exit 0
}

# Banner
Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "               FARIA AI TOOLKIT                 " -ForegroundColor Blue
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

$Arch = Get-SystemArchitecture
Write-Host "System detected: Windows ($Arch)" -ForegroundColor Yellow
Write-Host "Install directory: $InstallDir" -ForegroundColor Yellow
Write-Host ""

# Feature selection
Write-Host "Available features:" -ForegroundColor Blue
Write-Host ""
Write-Host "  idp  - Intelligent Document Processing (~630 MB)" -ForegroundColor Green
Write-Host "         OpenCV, Tesseract, Leptonica, MuPDF, ONNX Runtime,"
Write-Host "         DETR model (layout detection), Nemotron model (tables), CLIP model"
Write-Host ""
Write-Host "  chat - Conversational AI (~535 MB)" -ForegroundColor Green
Write-Host "         llama.cpp, Qwen 2.5 model"
Write-Host ""

# Prompt for features if not specified
if ([string]::IsNullOrEmpty($Features)) {
    if (Test-Interactive) {
        Write-Host "Which features do you want to install?" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  1) idp only      - Document processing"
        Write-Host "  2) chat only     - Conversational AI"
        Write-Host "  3) idp + chat    - Both features"
        Write-Host "  4) Cancel"
        Write-Host ""
        $choice = Read-Host "Enter choice [1-4]"
        switch ($choice) {
            "1" { $Features = "idp" }
            "2" { $Features = "chat" }
            "3" { $Features = "idp,chat" }
            default {
                Write-Host "Installation cancelled."
                exit 0
            }
        }
    } else {
        Write-Host "Error: -Features parameter required in non-interactive mode" -ForegroundColor Red
        exit 1
    }
}

# Normalize "all"
if ($Features -eq "all") {
    $Features = "idp,chat"
}

# Parse features
$InstallIDP = $Features -match "idp"
$InstallChat = $Features -match "chat"

if (-not $InstallIDP -and -not $InstallChat) {
    Write-Host "Error: No valid features selected" -ForegroundColor Red
    exit 1
}

# Ask about LLM for IDP
$InstallIDPLLM = $false
if ($InstallIDP -and -not $WithLLM) {
    if (Test-Interactive) {
        Write-Host ""
        Write-Host "Would you like to install LLM support for IDP?" -ForegroundColor Yellow
        Write-Host "  This enables advanced document understanding capabilities."
        Write-Host "  (Requires additional ~500 MB disk space)"
        Write-Host ""
        if (Confirm-Action -Prompt "Install LLM for IDP? (y/N)") {
            $InstallIDPLLM = $true
        }
    }
} elseif ($WithLLM) {
    $InstallIDPLLM = $true
}

# Summary
Write-Host ""
Write-Host "Installation summary:" -ForegroundColor Blue
Write-Host "  - IDP (Document Processing): $(if ($InstallIDP) { 'yes' } else { 'no' })"
if ($InstallIDP) {
    Write-Host "    - LLM support: $(if ($InstallIDPLLM) { 'yes' } else { 'no' })"
    Write-Host "    - Model source: $(if ($System) { 'HuggingFace download (-System)' } else { 'local Python export' })"
}
Write-Host "  - Chat (Conversational AI): $(if ($InstallChat) { 'yes' } else { 'no' })"
Write-Host "  - GPU support: $(if ($GPU) { 'yes' } else { 'no' })"
Write-Host ""

if (Test-Interactive) {
    if (-not (Confirm-Action -Prompt "Continue with installation? (Y/n)" -Default "y")) {
        Write-Host "Installation cancelled."
        exit 0
    }
}

Write-Host ""

# Create install directory
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null

# Install IDP
if ($InstallIDP) {
    Write-Step -Step 1 -Total 3 -Name "Installing IDP Feature"

    try {
        Invoke-InstallIDP -InstallDir $InstallDir -GPU:$GPU -WithLLM:$InstallIDPLLM -System:$System
        Write-Host "IDP Feature installed successfully" -ForegroundColor Green
    } catch {
        Write-Host "IDP Feature installation failed: $_" -ForegroundColor Red
    }
    Write-Host ""
}

# Install Chat
if ($InstallChat) {
    Write-Step -Step 2 -Total 3 -Name "Installing Chat Feature"

    try {
        Invoke-InstallChat -InstallDir $InstallDir
        Write-Host "Chat Feature installed successfully" -ForegroundColor Green
    } catch {
        Write-Host "Chat Feature installation failed: $_" -ForegroundColor Red
    }
    Write-Host ""
}

# Verify
Write-Step -Step 3 -Total 3 -Name "Verifying Installation"

Invoke-Verify -InstallDir $InstallDir

# Cleanup
Remove-ModelsCache

# Final message
Write-SuccessBanner -Text "Installation Complete!"

Write-Host "Installed features:" -ForegroundColor Yellow
if ($InstallIDP) {
    Write-Host "  - IDP - OpenCV, Tesseract, MuPDF, ONNX Runtime, DETR, Nemotron, CLIP"
}
if ($InstallChat) {
    Write-Host "  - Chat - llama.cpp, Qwen 2.5"
}
Write-Host ""
Write-Host "Open a new PowerShell session for PATH and env var changes to take effect." -ForegroundColor Yellow
Write-Host ""
Write-Host "For more information, see: https://github.com/exto360-inc/faria"
Write-Host ""
