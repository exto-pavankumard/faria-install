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

# Build date: 2026-01-23T19:47:45Z
# GitHub URL: https://raw.githubusercontent.com/exto360-inc/faria-install/main

param(
    [string]$Features = "",
    [string]$InstallDir = "$env:USERPROFILE\.faria",
    [switch]$GPU,
    [switch]$WithLLM,
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
        [switch]$WithLLM
    )

    
    param(
        [switch]$Help
    )
    
    if ($Help) {
        Write-Host "Faria Python Setup Script"
        Write-Host ""
        Write-Host "Usage: `$PythonCmd = & .\setup-python.ps1"
        Write-Host ""
        Write-Host "Ensures Python 3.12.x is available for onnxruntime compatibility."
        Write-Host "Returns the path to the Python interpreter."
        exit 0
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
            exit 1
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
            exit 1
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
                exit 1
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
        exit 1
    }
    
    # Return the path
    return $pythonPath
}

# ============================================================================
# Invoke-InstallOpenCV - from install-opencv.ps1
# ============================================================================
function Invoke-InstallOpenCV {
    param(
        [string]$InstallDir = "$env:USERPROFILE\.faria",
        [switch]$GPU,
        [switch]$WithLLM
    )

    
    param(
        [string]$InstallDir = "$env:USERPROFILE\.faria",
        [switch]$Help
    )
    
    if ($Help) {
        Write-Host "Faria OpenCV Installation Script"
        Write-Host ""
        Write-Host "Usage: .\install-opencv.ps1 [OPTIONS]"
        Write-Host ""
        Write-Host "Options:"
        Write-Host "  -InstallDir DIR  Install to DIR (default: $env:USERPROFILE\.faria)"
        Write-Host "  -Help            Show this help message"
        Write-Host ""
        Write-Host "This script installs OpenCV using pre-built binaries or Chocolatey."
        exit 0
    }
    
    Write-Host "========================================" -ForegroundColor Blue
    Write-Host "  Faria OpenCV Installation" -ForegroundColor Blue
    Write-Host "========================================" -ForegroundColor Blue
    Write-Host ""
    
    # OpenCV version
    $OpenCVVersion = "4.10.0"
    $OpenCVDir = "$InstallDir\lib\opencv"
    
    # Detect architecture
    $Arch = [System.Environment]::GetEnvironmentVariable("PROCESSOR_ARCHITECTURE")
    Write-Host "Detecting system..." -ForegroundColor Yellow
    Write-Host "  Architecture: $Arch"
    Write-Host ""
    
    # Check if OpenCV is already installed
    $ExistingOpenCV = $null
    
    # Check in install directory
    if (Test-Path "$OpenCVDir\build\x64\vc16\bin\opencv_world*.dll") {
        $ExistingOpenCV = (Get-Item "$OpenCVDir\build\x64\vc16\bin\opencv_world*.dll" | Select-Object -First 1).Name
    }
    
    # Check via environment variable
    if (-not $ExistingOpenCV -and $env:OPENCV_DIR) {
        if (Test-Path "$env:OPENCV_DIR\build\x64\vc16\bin\opencv_world*.dll") {
            $ExistingOpenCV = (Get-Item "$env:OPENCV_DIR\build\x64\vc16\bin\opencv_world*.dll" | Select-Object -First 1).Name
            Write-Host "OpenCV is already installed:" -ForegroundColor Green
            Write-Host "  Found: $ExistingOpenCV"
            Write-Host "  Location: $env:OPENCV_DIR"
            Write-Host ""
            $response = Read-Host "Do you want to reinstall? (y/N)"
            if ($response -ne 'y' -and $response -ne 'Y') {
                Write-Host "Skipping installation." -ForegroundColor Green
                exit 0
            }
        }
    }
    
    if ($ExistingOpenCV -and -not $env:OPENCV_DIR) {
        Write-Host "OpenCV is already installed:" -ForegroundColor Green
        Write-Host "  Found: $ExistingOpenCV"
        Write-Host "  Location: $OpenCVDir"
        Write-Host ""
        $response = Read-Host "Do you want to reinstall? (y/N)"
        if ($response -ne 'y' -and $response -ne 'Y') {
            Write-Host "Skipping installation." -ForegroundColor Green
            exit 0
        }
    }
    
    # Create install directory
    New-Item -ItemType Directory -Force -Path $OpenCVDir | Out-Null
    
    # Try to install via Chocolatey first (if available)
    $ChocoCmd = Get-Command choco -ErrorAction SilentlyContinue
    if ($ChocoCmd) {
        Write-Host "Chocolatey detected. Installing OpenCV via Chocolatey..." -ForegroundColor Yellow
        Write-Host ""
    
        try {
            choco install opencv -y
            if ($LASTEXITCODE -eq 0) {
                Write-Host ""
                Write-Host "========================================" -ForegroundColor Green
                Write-Host "  Installation Complete!" -ForegroundColor Green
                Write-Host "========================================" -ForegroundColor Green
                Write-Host ""
                Write-Host "OpenCV has been installed via Chocolatey."
                Write-Host "The OPENCV_DIR environment variable should be set automatically."
                Write-Host ""
                exit 0
            }
        } catch {
            Write-Host "Chocolatey installation failed, falling back to manual download..." -ForegroundColor Yellow
        }
    }
    
    # Download pre-built binaries
    Write-Host "Downloading OpenCV $OpenCVVersion pre-built binaries..." -ForegroundColor Yellow
    Write-Host ""
    
    $OpenCVAsset = "opencv-$OpenCVVersion-windows.exe"
    $OpenCVUrl = "https://github.com/opencv/opencv/releases/download/$OpenCVVersion/$OpenCVAsset"
    $DownloadPath = "$env:TEMP\$OpenCVAsset"
    
    try {
        Write-Host "  Downloading from: $OpenCVUrl"
        Write-Host "  This may take a few minutes (~250 MB)..."
        Write-Host ""
    
        # Use BITS for better download performance
        $BitsJob = Start-BitsTransfer -Source $OpenCVUrl -Destination $DownloadPath -ErrorAction Stop
    
        Write-Host "  Download complete." -ForegroundColor Green
        Write-Host ""
    } catch {
        # Fallback to Invoke-WebRequest
        Write-Host "  BITS transfer failed, using WebRequest..." -ForegroundColor Yellow
        try {
            $ProgressPreference = 'SilentlyContinue'
            Invoke-WebRequest -Uri $OpenCVUrl -OutFile $DownloadPath -UseBasicParsing
            $ProgressPreference = 'Continue'
            Write-Host "  Download complete." -ForegroundColor Green
            Write-Host ""
        } catch {
            Write-Host "  Download failed: $_" -ForegroundColor Red
            Write-Host ""
            Write-Host "Please download OpenCV manually from:" -ForegroundColor Yellow
            Write-Host "  https://opencv.org/releases/"
            Write-Host ""
            Write-Host "Or install via Chocolatey:" -ForegroundColor Yellow
            Write-Host "  choco install opencv"
            Write-Host ""
            exit 1
        }
    }
    
    # Extract the self-extracting archive
    Write-Host "Extracting OpenCV..." -ForegroundColor Yellow
    
    try {
        # The OpenCV Windows release is a self-extracting 7z archive
        # We can run it with -o to specify output directory
        $ExtractDir = "$env:TEMP\opencv-extract"
        if (Test-Path $ExtractDir) {
            Remove-Item -Recurse -Force $ExtractDir
        }
    
        # Run the self-extracting exe with silent extraction
        Start-Process -FilePath $DownloadPath -ArgumentList "-o`"$ExtractDir`"", "-y" -Wait -NoNewWindow
    
        # Move the extracted opencv folder to install directory
        $ExtractedFolder = Get-ChildItem -Path $ExtractDir -Directory | Select-Object -First 1
        if ($ExtractedFolder) {
            if (Test-Path $OpenCVDir) {
                Remove-Item -Recurse -Force $OpenCVDir
            }
            Move-Item -Path $ExtractedFolder.FullName -Destination $OpenCVDir -Force
            Write-Host "  Extracted to: $OpenCVDir" -ForegroundColor Green
        } else {
            throw "Could not find extracted OpenCV folder"
        }
    
        # Cleanup
        Remove-Item -Path $DownloadPath -Force -ErrorAction SilentlyContinue
        Remove-Item -Recurse -Force $ExtractDir -ErrorAction SilentlyContinue
    
    } catch {
        Write-Host "  Extraction failed: $_" -ForegroundColor Red
        Write-Host ""
        Write-Host "The OpenCV installer may require manual extraction." -ForegroundColor Yellow
        Write-Host "Please run: $DownloadPath"
        Write-Host "And extract to: $OpenCVDir"
        Write-Host ""
        exit 1
    }
    
    # Verify installation
    Write-Host ""
    Write-Host "Verifying installation..." -ForegroundColor Yellow
    
    $OpenCVDll = Get-ChildItem -Path "$OpenCVDir" -Recurse -Filter "opencv_world*.dll" -ErrorAction SilentlyContinue | Select-Object -First 1
    
    if ($OpenCVDll) {
        Write-Host "  OpenCV: OK" -ForegroundColor Green
        Write-Host "    Found: $($OpenCVDll.Name)"
        Write-Host "    Path: $($OpenCVDll.DirectoryName)"
    } else {
        Write-Host "  OpenCV: Could not verify installation" -ForegroundColor Yellow
        Write-Host "    Please check $OpenCVDir manually"
    }
    
    # Print success message
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  Installation Complete!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "OpenCV has been installed to: $OpenCVDir"
    Write-Host ""
    Write-Host "To use OpenCV, set the environment variable:" -ForegroundColor Yellow
    Write-Host "  `$env:OPENCV_DIR = `"$OpenCVDir`""
    Write-Host ""
    Write-Host "Or add to your system PATH:" -ForegroundColor Yellow
    if ($OpenCVDll) {
        Write-Host "  $($OpenCVDll.DirectoryName)"
    }
    Write-Host ""
}

# ============================================================================
# Invoke-InstallTesseract - from install-tesseract.ps1
# ============================================================================
function Invoke-InstallTesseract {
    param(
        [string]$InstallDir = "$env:USERPROFILE\.faria",
        [switch]$GPU,
        [switch]$WithLLM
    )

    
    param(
        [string]$InstallDir = "C:\Program Files\Tesseract-OCR",
        [switch]$Help
    )
    
    # Configuration
    $TesseractVersion = "5.5.0"
    $TesseractDate = "20241111"
    
    if ($Help) {
        Write-Host "Faria Tesseract OCR Installation Script"
        Write-Host ""
        Write-Host "Usage: .\install-tesseract.ps1 [OPTIONS]"
        Write-Host ""
        Write-Host "Options:"
        Write-Host "  -InstallDir DIR  Install to DIR (default: C:\Program Files\Tesseract-OCR)"
        Write-Host "  -Help            Show this help message"
        Write-Host ""
        Write-Host "This script downloads Tesseract from UB-Mannheim releases."
        exit 0
    }
    
    Write-Host "========================================" -ForegroundColor Blue
    Write-Host "  Faria Tesseract OCR Installation" -ForegroundColor Blue
    Write-Host "========================================" -ForegroundColor Blue
    Write-Host ""
    
    # Check if running as administrator
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    if (-not $isAdmin -and $InstallDir -like "C:\Program Files*") {
        Write-Host "Warning: Installing to Program Files requires administrator privileges." -ForegroundColor Yellow
        Write-Host "Please run this script as Administrator, or use -InstallDir to specify a different location." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Example: .\install-tesseract.ps1 -InstallDir `"$env:USERPROFILE\.faria\tesseract`"" -ForegroundColor Yellow
        exit 1
    }
    
    # Detect architecture
    $Arch = [System.Environment]::GetEnvironmentVariable("PROCESSOR_ARCHITECTURE")
    
    Write-Host "Detecting system..." -ForegroundColor Yellow
    Write-Host "  OS: Windows"
    Write-Host "  Architecture: $Arch"
    
    # Check if Tesseract is already installed
    $existingTesseract = Get-Command tesseract -ErrorAction SilentlyContinue
    if ($existingTesseract) {
        $version = & tesseract --version 2>&1 | Select-Object -First 1
        Write-Host ""
        Write-Host "Tesseract is already installed:" -ForegroundColor Green
        Write-Host "  $version"
        Write-Host "  Path: $($existingTesseract.Source)"
        Write-Host ""
        $response = Read-Host "Do you want to reinstall/upgrade? (y/N)"
        if ($response -ne 'y' -and $response -ne 'Y') {
            Write-Host "Skipping installation." -ForegroundColor Green
            exit 0
        }
    }
    
    # Determine download URL
    switch ($Arch) {
        "AMD64" {
            $TesseractAsset = "tesseract-ocr-w64-setup-$TesseractVersion.$TesseractDate.exe"
        }
        "x86" {
            $TesseractAsset = "tesseract-ocr-w32-setup-$TesseractVersion.$TesseractDate.exe"
        }
        default {
            Write-Host "Unsupported architecture: $Arch" -ForegroundColor Red
            exit 1
        }
    }
    
    $TesseractUrl = "https://github.com/UB-Mannheim/tesseract/releases/download/v$TesseractVersion/$TesseractAsset"
    
    Write-Host ""
    Write-Host "Installation configuration:" -ForegroundColor Yellow
    Write-Host "  Install directory: $InstallDir"
    Write-Host "  Tesseract version: $TesseractVersion"
    Write-Host "  Installer: $TesseractAsset"
    Write-Host ""
    
    # Create temp directory
    $TempDir = Join-Path $env:TEMP "faria-tesseract-install-$(Get-Random)"
    New-Item -ItemType Directory -Force -Path $TempDir | Out-Null
    
    try {
        # Download Tesseract installer
        Write-Host "Downloading Tesseract installer..." -ForegroundColor Yellow
        Write-Host "  URL: $TesseractUrl"
    
        $InstallerPath = Join-Path $TempDir $TesseractAsset
    
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $TesseractUrl -OutFile $InstallerPath -UseBasicParsing
        $ProgressPreference = 'Continue'
    
        Write-Host "Download complete." -ForegroundColor Green
        Write-Host ""
        Write-Host "Running installer..." -ForegroundColor Yellow
        Write-Host "  Please follow the installer prompts."
        Write-Host "  Recommended: Install to default location and add to PATH."
        Write-Host ""
    
        # Run installer
        Start-Process -FilePath $InstallerPath -Wait
    
        # Verify installation
        Write-Host ""
        Write-Host "Verifying installation..." -ForegroundColor Yellow
    
        # Refresh PATH
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    
        $tesseractCmd = Get-Command tesseract -ErrorAction SilentlyContinue
        if ($tesseractCmd) {
            $version = & tesseract --version 2>&1 | Select-Object -First 1
            Write-Host "  Tesseract: OK" -ForegroundColor Green
            Write-Host "    Version: $version"
            Write-Host "    Path: $($tesseractCmd.Source)"
        } else {
            Write-Host "  Tesseract: Not found in PATH" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "Tesseract may have been installed but not added to PATH." -ForegroundColor Yellow
            Write-Host "Please add the installation directory to your PATH manually,"
            Write-Host "or restart your terminal/PowerShell session."
        }
    
        # Print success message
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Green
        Write-Host "  Installation Complete!" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "Tesseract OCR has been installed."
        Write-Host ""
        Write-Host "If tesseract is not found, you may need to:" -ForegroundColor Yellow
        Write-Host "  1. Add the installation directory to your PATH"
        Write-Host "  2. Restart your terminal/PowerShell session"
        Write-Host ""
        Write-Host "Default installation path: C:\Program Files\Tesseract-OCR"
        Write-Host ""
    
    } finally {
        # Cleanup
        if (Test-Path $TempDir) {
            Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# ============================================================================
# Invoke-InstallMuPDF - from install-mupdf.ps1
# ============================================================================
function Invoke-InstallMuPDF {
    param(
        [string]$InstallDir = "$env:USERPROFILE\.faria",
        [switch]$GPU,
        [switch]$WithLLM
    )

    
    param(
        [string]$InstallDir = "$env:USERPROFILE\.faria",
        [switch]$Help
    )
    
    if ($Help) {
        Write-Host "Faria MuPDF Installation Script"
        Write-Host ""
        Write-Host "Usage: .\install-mupdf.ps1 [OPTIONS]"
        Write-Host ""
        Write-Host "Options:"
        Write-Host "  -InstallDir DIR  Install to DIR (default: $env:USERPROFILE\.faria)"
        Write-Host "  -Help            Show this help message"
        Write-Host ""
        Write-Host "This script installs MuPDF using pre-built binaries or Chocolatey."
        exit 0
    }
    
    Write-Host "========================================" -ForegroundColor Blue
    Write-Host "  Faria MuPDF Installation" -ForegroundColor Blue
    Write-Host "========================================" -ForegroundColor Blue
    Write-Host ""
    
    # MuPDF version
    $MuPDFVersion = "1.24.9"
    $BinDir = "$InstallDir\bin"
    
    # Detect architecture
    $Arch = [System.Environment]::GetEnvironmentVariable("PROCESSOR_ARCHITECTURE")
    Write-Host "Detecting system..." -ForegroundColor Yellow
    Write-Host "  Architecture: $Arch"
    Write-Host ""
    
    # Check if MuPDF is already installed
    $MuToolCmd = Get-Command mutool -ErrorAction SilentlyContinue
    $MuToolPath = "$BinDir\mutool.exe"
    
    if ($MuToolCmd) {
        $MuToolVersion = (& mutool -v 2>&1 | Select-Object -First 1)
        Write-Host "MuPDF is already installed:" -ForegroundColor Green
        Write-Host "  Version: $MuToolVersion"
        Write-Host "  Path: $($MuToolCmd.Source)"
        Write-Host ""
        $response = Read-Host "Do you want to reinstall? (y/N)"
        if ($response -ne 'y' -and $response -ne 'Y') {
            Write-Host "Skipping installation." -ForegroundColor Green
            exit 0
        }
    } elseif (Test-Path $MuToolPath) {
        Write-Host "MuPDF is already installed:" -ForegroundColor Green
        Write-Host "  Path: $MuToolPath"
        Write-Host ""
        $response = Read-Host "Do you want to reinstall? (y/N)"
        if ($response -ne 'y' -and $response -ne 'Y') {
            Write-Host "Skipping installation." -ForegroundColor Green
            exit 0
        }
    }
    
    # Create directories
    New-Item -ItemType Directory -Force -Path $BinDir | Out-Null
    
    # Try to install via Chocolatey first (if available)
    $ChocoCmd = Get-Command choco -ErrorAction SilentlyContinue
    if ($ChocoCmd) {
        Write-Host "Chocolatey detected. Installing MuPDF via Chocolatey..." -ForegroundColor Yellow
        Write-Host ""
    
        try {
            choco install mupdf -y
            if ($LASTEXITCODE -eq 0) {
                Write-Host ""
                Write-Host "========================================" -ForegroundColor Green
                Write-Host "  Installation Complete!" -ForegroundColor Green
                Write-Host "========================================" -ForegroundColor Green
                Write-Host ""
                Write-Host "MuPDF has been installed via Chocolatey."
                Write-Host "The mutool command should now be available in PATH."
                Write-Host ""
                exit 0
            }
        } catch {
            Write-Host "Chocolatey installation failed, falling back to manual download..." -ForegroundColor Yellow
        }
    }
    
    # Determine download URL based on architecture
    if ($Arch -eq "ARM64") {
        # ARM64 builds might not be available, try x64
        Write-Host "Note: ARM64 builds may not be available, using x64 version..." -ForegroundColor Yellow
        $MuPDFAsset = "mupdf-$MuPDFVersion-windows.zip"
    } else {
        $MuPDFAsset = "mupdf-$MuPDFVersion-windows.zip"
    }
    
    # MuPDF official download URL
    $MuPDFUrl = "https://mupdf.com/downloads/archive/$MuPDFAsset"
    $DownloadPath = "$env:TEMP\$MuPDFAsset"
    
    Write-Host "Downloading MuPDF $MuPDFVersion..." -ForegroundColor Yellow
    Write-Host "  From: $MuPDFUrl"
    Write-Host ""
    
    try {
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $MuPDFUrl -OutFile $DownloadPath -UseBasicParsing
        $ProgressPreference = 'Continue'
        Write-Host "  Download complete." -ForegroundColor Green
        Write-Host ""
    } catch {
        Write-Host "  Download failed: $_" -ForegroundColor Red
        Write-Host ""
        Write-Host "Please download MuPDF manually from:" -ForegroundColor Yellow
        Write-Host "  https://mupdf.com/downloads/index.html"
        Write-Host ""
        Write-Host "Or install via Chocolatey:" -ForegroundColor Yellow
        Write-Host "  choco install mupdf"
        Write-Host ""
        exit 1
    }
    
    # Extract the archive
    Write-Host "Extracting MuPDF..." -ForegroundColor Yellow
    
    try {
        $ExtractDir = "$env:TEMP\mupdf-extract"
        if (Test-Path $ExtractDir) {
            Remove-Item -Recurse -Force $ExtractDir
        }
    
        Expand-Archive -Path $DownloadPath -DestinationPath $ExtractDir -Force
    
        # Find the extracted folder
        $ExtractedFolder = Get-ChildItem -Path $ExtractDir -Directory | Select-Object -First 1
    
        if ($ExtractedFolder) {
            # Copy mutool.exe to bin directory
            $MuToolSource = Get-ChildItem -Path $ExtractedFolder.FullName -Recurse -Filter "mutool.exe" | Select-Object -First 1
            if ($MuToolSource) {
                Copy-Item -Path $MuToolSource.FullName -Destination $MuToolPath -Force
                Write-Host "  Installed mutool.exe to: $MuToolPath" -ForegroundColor Green
            } else {
                throw "Could not find mutool.exe in extracted archive"
            }
    
            # Also copy mudraw if available
            $MuDrawSource = Get-ChildItem -Path $ExtractedFolder.FullName -Recurse -Filter "mudraw.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($MuDrawSource) {
                Copy-Item -Path $MuDrawSource.FullName -Destination "$BinDir\mudraw.exe" -Force
            }
    
            # Copy mupdf-gl if available (GUI viewer)
            $MuPDFGLSource = Get-ChildItem -Path $ExtractedFolder.FullName -Recurse -Filter "mupdf-gl.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($MuPDFGLSource) {
                Copy-Item -Path $MuPDFGLSource.FullName -Destination "$BinDir\mupdf-gl.exe" -Force
            }
        } else {
            throw "Could not find extracted MuPDF folder"
        }
    
        # Cleanup
        Remove-Item -Path $DownloadPath -Force -ErrorAction SilentlyContinue
        Remove-Item -Recurse -Force $ExtractDir -ErrorAction SilentlyContinue
    
    } catch {
        Write-Host "  Extraction failed: $_" -ForegroundColor Red
        Write-Host ""
        Write-Host "Please extract manually and copy mutool.exe to:" -ForegroundColor Yellow
        Write-Host "  $BinDir"
        Write-Host ""
        exit 1
    }
    
    # Verify installation
    Write-Host ""
    Write-Host "Verifying installation..." -ForegroundColor Yellow
    
    if (Test-Path $MuToolPath) {
        # Try to get version
        try {
            $Version = (& $MuToolPath -v 2>&1 | Select-Object -First 1)
            Write-Host "  MuPDF: OK" -ForegroundColor Green
            Write-Host "    Version: $Version"
            Write-Host "    Path: $MuToolPath"
        } catch {
            Write-Host "  MuPDF: OK (installed)" -ForegroundColor Green
            Write-Host "    Path: $MuToolPath"
        }
    } else {
        Write-Host "  MuPDF: Could not verify installation" -ForegroundColor Yellow
    }
    
    # Print success message
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  Installation Complete!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "MuPDF has been installed to: $BinDir"
    Write-Host ""
    Write-Host "To use MuPDF commands globally, add to your PATH:" -ForegroundColor Yellow
    Write-Host "  `$env:PATH += `";$BinDir`""
    Write-Host ""
    Write-Host "Or Faria will automatically detect it in: $InstallDir"
    Write-Host ""
}

# ============================================================================
# Invoke-InstallOnnxRuntime - from install-onnxruntime.ps1
# ============================================================================
function Invoke-InstallOnnxRuntime {
    param(
        [string]$InstallDir = "$env:USERPROFILE\.faria",
        [switch]$GPU,
        [switch]$WithLLM
    )

    
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
}

# ============================================================================
# Invoke-InstallModels - from install-models.ps1
# ============================================================================
function Invoke-InstallModels {
    param(
        [string]$InstallDir = "$env:USERPROFILE\.faria",
        [switch]$GPU,
        [switch]$WithLLM
    )

    
    param(
        [string]$InstallDir = "$env:USERPROFILE\.faria",
        [switch]$SkipDETR,
        [switch]$SkipNemotron,
        [switch]$KeepVenv,
        [switch]$Help
    )
    
    if ($Help) {
        Write-Host "Faria ML Models Installation Script"
        Write-Host ""
        Write-Host "Usage: .\install-models.ps1 [OPTIONS]"
        Write-Host ""
        Write-Host "Options:"
        Write-Host "  -InstallDir DIR   Install to DIR (default: $env:USERPROFILE\.faria)"
        Write-Host "  -SkipDETR         Skip DETR model installation"
        Write-Host "  -SkipNemotron     Skip Nemotron model installation"
        Write-Host "  -KeepVenv         Keep Python virtual environment after installation"
        Write-Host "  -Help             Show this help message"
        Write-Host ""
        Write-Host "Prerequisites:"
        Write-Host "  - Python 3.8+"
        Write-Host "  - Git with Git LFS (for Nemotron)"
        exit 0
    }
    
    Write-Host "========================================" -ForegroundColor Blue
    Write-Host "  Faria ML Models Installation" -ForegroundColor Blue
    Write-Host "========================================" -ForegroundColor Blue
    Write-Host ""
    
    # Get script and repo directories
    # The repo root is the parent of scripts/
    $RepoDir = Split-Path -Parent $ScriptDir
    
    Write-Host "Detecting system..." -ForegroundColor Yellow
    Write-Host "  OS: Windows"
    Write-Host "  Repository: $RepoDir"
    Write-Host ""
    
    # Check prerequisites
    Write-Host "Checking prerequisites..." -ForegroundColor Yellow
    
    # Check Python (requires 3.12.x for onnxruntime compatibility)
    $PythonCmd = & "Initialize-Python"
    
    if (-not $PythonCmd -or -not (Test-Path $PythonCmd -ErrorAction SilentlyContinue)) {
        # setup-python.ps1 might return a command name instead of path
        if (-not (Get-Command $PythonCmd -ErrorAction SilentlyContinue)) {
            Write-Host "Error: Python 3.12 setup failed" -ForegroundColor Red
            exit 1
        }
    }
    
    $PythonVersion = & $PythonCmd --version 2>&1
    
    # Check Git
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Host "Error: Git not found. Please install Git." -ForegroundColor Red
        exit 1
    }
    $GitVersion = (git --version) -replace 'git version ', ''
    Write-Host "  Git: $GitVersion" -ForegroundColor Green
    
    # Check Git LFS (required for Nemotron)
    if (-not $SkipNemotron) {
        try {
            $null = & git lfs version 2>&1
            Write-Host "  Git LFS: installed" -ForegroundColor Green
        } catch {
            Write-Host "Error: Git LFS not found. Please install Git LFS." -ForegroundColor Red
            Write-Host ""
            Write-Host "Installation: https://git-lfs.github.com/"
            Write-Host "Then run: git lfs install"
            exit 1
        }
    }
    
    Write-Host ""
    Write-Host "Installation configuration:" -ForegroundColor Yellow
    Write-Host "  Install directory: $InstallDir"
    Write-Host "  DETR: $(if ($SkipDETR) { 'skip' } else { 'install' })"
    Write-Host "  Nemotron: $(if ($SkipNemotron) { 'skip' } else { 'install' })"
    Write-Host ""
    
    # Create directories
    New-Item -ItemType Directory -Force -Path "$InstallDir\models" | Out-Null
    
    # Create temp directory for work
    $WorkDir = Join-Path $env:TEMP "faria-models-install-$(Get-Random)"
    New-Item -ItemType Directory -Force -Path $WorkDir | Out-Null
    $VenvDir = Join-Path $WorkDir "venv"
    
    try {
        # Create virtual environment
        Write-Host "Creating Python virtual environment..." -ForegroundColor Yellow
        & $PythonCmd -m venv $VenvDir
    
        # Activate virtual environment
        $ActivateScript = Join-Path $VenvDir "Scripts\Activate.ps1"
        . $ActivateScript
    
        # Upgrade pip
        Write-Host "Upgrading pip..." -ForegroundColor Yellow
        & pip install --upgrade pip -q
    
        # ========================================================================
        # Install DETR Model
        # ========================================================================
        if (-not $SkipDETR) {
            Write-Host ""
            Write-Host "----------------------------------------" -ForegroundColor Blue
            Write-Host "  Installing DETR Model" -ForegroundColor Blue
            Write-Host "----------------------------------------" -ForegroundColor Blue
            Write-Host ""
    
            $DETRModelPath = "$InstallDir\models\detr_layout_detection.onnx"
    
            # Check if already exists
            if (Test-Path $DETRModelPath) {
                Write-Host "DETR model already exists at: $DETRModelPath" -ForegroundColor Yellow
                $response = Read-Host "Do you want to reinstall? (y/N)"
                if ($response -ne 'y' -and $response -ne 'Y') {
                    Write-Host "Skipping DETR installation." -ForegroundColor Green
                    $SkipDETR = $true
                }
            }
    
            if (-not $SkipDETR) {
                Write-Host "Installing DETR dependencies..." -ForegroundColor Yellow
                & pip install -r "$RepoDir\models\requirements-detr.txt" -q
    
                Write-Host "Exporting DETR model to ONNX..." -ForegroundColor Yellow
                Write-Host "  This may take a few minutes on first run (downloading model)..."
    
                # Export script is in models/ directory in this repo
                $DETRExportScript = Join-Path $RepoDir "models\export_detr_layout_onnx.py"
    
                if (-not (Test-Path $DETRExportScript)) {
                    Write-Host "Error: DETR export script not found at: $DETRExportScript" -ForegroundColor Red
                    exit 1
                }
    
                Push-Location $WorkDir
                & python $DETRExportScript
                Pop-Location
    
                # Find and move the output file
                $DETROutput = Get-ChildItem -Path $WorkDir -Filter "*.onnx" -Recurse |
                              Where-Object { $_.LastWriteTime -gt (Get-Item $VenvDir).LastWriteTime } |
                              Select-Object -First 1
    
                if (-not $DETROutput) {
                    # Try common output names
                    foreach ($name in @("detr_layout_detection.onnx", "model.onnx", "detr.onnx")) {
                        $testPath = Join-Path $WorkDir $name
                        if (Test-Path $testPath) {
                            $DETROutput = Get-Item $testPath
                            break
                        }
                    }
                }
    
                if ($DETROutput) {
                    Move-Item -Path $DETROutput.FullName -Destination $DETRModelPath -Force
                    $DETRSize = [math]::Round((Get-Item $DETRModelPath).Length / 1MB, 1)
                    Write-Host "  DETR model installed: $DETRModelPath ($DETRSize MB)" -ForegroundColor Green
                } else {
                    Write-Host "Error: DETR ONNX file not found after export" -ForegroundColor Red
                    exit 1
                }
            }
        }
    
        # ========================================================================
        # Install Nemotron Model
        # ========================================================================
        if (-not $SkipNemotron) {
            Write-Host ""
            Write-Host "----------------------------------------" -ForegroundColor Blue
            Write-Host "  Installing Nemotron Model" -ForegroundColor Blue
            Write-Host "----------------------------------------" -ForegroundColor Blue
            Write-Host ""
    
            $NemotronModelPath = "$InstallDir\models\nemotron_table_structure.onnx"
    
            # Check if already exists
            if (Test-Path $NemotronModelPath) {
                Write-Host "Nemotron model already exists at: $NemotronModelPath" -ForegroundColor Yellow
                $response = Read-Host "Do you want to reinstall? (y/N)"
                if ($response -ne 'y' -and $response -ne 'Y') {
                    Write-Host "Skipping Nemotron installation." -ForegroundColor Green
                    $SkipNemotron = $true
                }
            }
    
            if (-not $SkipNemotron) {
                Write-Host "Cloning Nemotron repository from HuggingFace..." -ForegroundColor Yellow
                Write-Host "  This may take a while (downloading ~200MB model)..."
    
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
    
                # Export script is in models/ directory in this repo
                $NemotronExportScript = Join-Path $RepoDir "models\export_nemotron_onnx.py"
    
                if (-not (Test-Path $NemotronExportScript)) {
                    Write-Host "Error: Nemotron export script not found at: $NemotronExportScript" -ForegroundColor Red
                    exit 1
                }
    
                & python $NemotronExportScript
                Pop-Location
    
                # Find and move the output file
                $NemotronOutput = Get-ChildItem -Path $WorkDir -Filter "*.onnx" -Recurse |
                                  Where-Object { $_.LastWriteTime -gt (Get-Item $NemotronRepo).CreationTime } |
                                  Select-Object -First 1
    
                if (-not $NemotronOutput) {
                    # Try common output names
                    foreach ($name in @("nemotron_table_fixed.onnx", "nemotron_table_structure.onnx", "nemotron.onnx", "model.onnx")) {
                        foreach ($dir in @($WorkDir, $NemotronRepo)) {
                            $testPath = Join-Path $dir $name
                            if (Test-Path $testPath) {
                                $NemotronOutput = Get-Item $testPath
                                break
                            }
                        }
                        if ($NemotronOutput) { break }
                    }
                }
    
                if ($NemotronOutput) {
                    Move-Item -Path $NemotronOutput.FullName -Destination $NemotronModelPath -Force
                    $NemotronSize = [math]::Round((Get-Item $NemotronModelPath).Length / 1MB, 1)
                    Write-Host "  Nemotron model installed: $NemotronModelPath ($NemotronSize MB)" -ForegroundColor Green
                } else {
                    Write-Host "Error: Nemotron ONNX file not found after export" -ForegroundColor Red
                    exit 1
                }
            }
        }
    
        # Deactivate virtual environment
        deactivate
    
        # Verify installation
        Write-Host ""
        Write-Host "Verifying installation..." -ForegroundColor Yellow
    
        if (-not $SkipDETR -and (Test-Path "$InstallDir\models\detr_layout_detection.onnx")) {
            $DETRSize = [math]::Round((Get-Item "$InstallDir\models\detr_layout_detection.onnx").Length / 1MB, 1)
            Write-Host "  DETR: OK ($DETRSize MB)" -ForegroundColor Green
        } elseif ($SkipDETR) {
            Write-Host "  DETR: skipped" -ForegroundColor Yellow
        } else {
            Write-Host "  DETR: FAILED" -ForegroundColor Red
        }
    
        if (-not $SkipNemotron -and (Test-Path "$InstallDir\models\nemotron_table_structure.onnx")) {
            $NemotronSize = [math]::Round((Get-Item "$InstallDir\models\nemotron_table_structure.onnx").Length / 1MB, 1)
            Write-Host "  Nemotron: OK ($NemotronSize MB)" -ForegroundColor Green
        } elseif ($SkipNemotron) {
            Write-Host "  Nemotron: skipped" -ForegroundColor Yellow
        } else {
            Write-Host "  Nemotron: FAILED" -ForegroundColor Red
        }
    
        # Print success message
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Green
        Write-Host "  Installation Complete!" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "Installed models:"
        if (Test-Path "$InstallDir\models\detr_layout_detection.onnx") {
            Write-Host "  $InstallDir\models\detr_layout_detection.onnx"
        }
        if (Test-Path "$InstallDir\models\nemotron_table_structure.onnx") {
            Write-Host "  $InstallDir\models\nemotron_table_structure.onnx"
        }
        Write-Host ""
        Write-Host "Configuration Options:" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Option 1: Environment variables (recommended)"
        Write-Host "  Run these commands in PowerShell (or add to your profile):"
        Write-Host ""
        Write-Host "    `$env:FARIA_DETR_MODEL_PATH = `"$InstallDir\models\detr_layout_detection.onnx`""
        Write-Host "    `$env:FARIA_NEMOTRON_MODEL_PATH = `"$InstallDir\models\nemotron_table_structure.onnx`""
        Write-Host ""
        Write-Host "Option 2: Auto-detection"
        Write-Host "  Faria will automatically detect files in $env:USERPROFILE\.faria\ (no action needed)"
        Write-Host ""
    
    } finally {
        # Cleanup
        if (-not $KeepVenv -and (Test-Path $WorkDir)) {
            Write-Host "Cleaning up temporary files..." -ForegroundColor Yellow
            Remove-Item -Path $WorkDir -Recurse -Force -ErrorAction SilentlyContinue
        } elseif ($KeepVenv) {
            Write-Host "Keeping virtual environment at: $VenvDir" -ForegroundColor Yellow
        }
    }
}

# ============================================================================
# Invoke-InstallSLM - from install-slm.ps1
# ============================================================================
function Invoke-InstallSLM {
    param(
        [string]$InstallDir = "$env:USERPROFILE\.faria",
        [switch]$GPU,
        [switch]$WithLLM
    )

    
    param(
        [string]$InstallDir = "$env:USERPROFILE\.faria",
        [switch]$Help
    )
    
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
    
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $LlamaUrl -OutFile $LlamaZipPath -UseBasicParsing
        $ProgressPreference = 'Continue'
    
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
            $ProgressPreference = 'SilentlyContinue'
            Invoke-WebRequest -Uri $QwenModelUrl -OutFile $ModelPath -UseBasicParsing
            $ProgressPreference = 'Continue'
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
        [switch]$WithLLM
    )

    
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
    # Check IDP Dependencies (OpenCV, Tesseract, Leptonica, MuPDF)
    # ============================================================================
    Write-Host "IDP Dependencies:" -ForegroundColor Blue
    
    # Check OpenCV
    $OpenCVDir = "$InstallDir\lib\opencv"
    $OpenCVFound = $false
    $OpenCVPath = ""
    
    # Check in install directory
    $OpenCVDll = Get-ChildItem -Path "$OpenCVDir" -Recurse -Filter "opencv_world*.dll" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($OpenCVDll) {
        $OpenCVFound = $true
        $OpenCVPath = $OpenCVDll.FullName
    }
    
    # Check via environment variable
    if (-not $OpenCVFound -and $env:OPENCV_DIR) {
        $OpenCVDll = Get-ChildItem -Path "$env:OPENCV_DIR" -Recurse -Filter "opencv_world*.dll" -ErrorAction SilentlyContinue | Select-Object -First 1
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
        exit 1
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
        [switch]$WithLLM
    )

    
    param(
        [string]$InstallDir = "$env:USERPROFILE\.faria",
        [switch]$GPU,
        [switch]$WithLLM,
        [switch]$Help
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
        Write-Host "  -Help            Show this help message"
        Write-Host ""
        Write-Host "This script installs all dependencies for IDP (Intelligent Document Processing):"
        Write-Host "  - OpenCV           Image processing"
        Write-Host "  - Tesseract        OCR engine"
        Write-Host "  - Leptonica        Image library (with Tesseract)"
        Write-Host "  - MuPDF            PDF processing"
        Write-Host "  - ONNX Runtime     Model inference"
        Write-Host "  - DETR model       Layout detection"
        Write-Host "  - Nemotron model   Table extraction"
        exit 0
    }
    
    # Get script directory
    
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host "   Faria IDP Dependencies Installation" -ForegroundColor Blue
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "Install directory: $InstallDir" -ForegroundColor Yellow
    Write-Host ""
    
    # Track installation status
    $script:InstallFailed = $false
    $TotalSteps = 5
    if ($WithLLM) { $TotalSteps++ }
    $script:CurrentStep = 0
    
    # Helper function to run a step
    function Invoke-Step {
        param(
            [string]$StepName,
            [string]$Script,
            [string[]]$Arguments = @()
        )
    
        $script:CurrentStep++
        Write-Host ""
        Write-Host "-----------------------------------------------------------------" -ForegroundColor Blue
        Write-Host "  Step $($script:CurrentStep)/$TotalSteps`: $StepName" -ForegroundColor Blue
        Write-Host "-----------------------------------------------------------------" -ForegroundColor Blue
        Write-Host ""
    
        try {
            if ($Arguments.Count -gt 0) {
                & "$ScriptDir\$Script" @Arguments
            } else {
                & "$ScriptDir\$Script"
            }
            if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) {
                throw "Script returned exit code $LASTEXITCODE"
            }
            Write-Host "[OK] $StepName completed successfully" -ForegroundColor Green
        } catch {
            Write-Host "[X] $StepName failed: $_" -ForegroundColor Red
            $script:InstallFailed = $true
        }
    }
    
    # Create install directory
    New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
    
    # Step 1: Install OpenCV
    Invoke-Step -StepName "Installing OpenCV" -Script "install-opencv.ps1" -Arguments @("-InstallDir", $InstallDir)
    
    # Step 2: Install Tesseract (includes Leptonica)
    Invoke-Step -StepName "Installing Tesseract OCR" -Script "install-tesseract.ps1"
    
    # Step 3: Install MuPDF
    Invoke-Step -StepName "Installing MuPDF" -Script "install-mupdf.ps1" -Arguments @("-InstallDir", $InstallDir)
    
    # Step 4: Install ONNX Runtime
    $OnnxArgs = @("-InstallDir", $InstallDir)
    if ($GPU) { $OnnxArgs += "-GPU" }
    Invoke-Step -StepName "Installing ONNX Runtime" -Script "install-onnxruntime.ps1" -Arguments $OnnxArgs
    
    # Step 5: Install ML Models (DETR + Nemotron)
    Invoke-Step -StepName "Installing ML Models" -Script "install-models.ps1" -Arguments @("-InstallDir", $InstallDir)
    
    # Step 6 (optional): Install LLM for IDP
    if ($WithLLM) {
        Invoke-Step -StepName "Installing LLM for IDP" -Script "install-slm.ps1" -Arguments @("-InstallDir", $InstallDir)
    }
    
    # Final Summary
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
    Write-Host "  - OpenCV       - Image processing"
    Write-Host "  - Tesseract    - OCR engine"
    Write-Host "  - Leptonica    - Image library"
    Write-Host "  - MuPDF        - PDF processing"
    Write-Host "  - ONNX Runtime - Model inference"
    Write-Host "  - DETR model   - Layout detection"
    Write-Host "  - Nemotron     - Table extraction"
    if ($WithLLM) {
        Write-Host "  - LLM          - Advanced document understanding"
    }
    Write-Host ""
    
    if ($script:InstallFailed) {
        exit 1
    }
}

# ============================================================================
# Invoke-InstallChat - from install-chat.ps1
# ============================================================================
function Invoke-InstallChat {
    param(
        [string]$InstallDir = "$env:USERPROFILE\.faria",
        [switch]$GPU,
        [switch]$WithLLM
    )

    
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
        exit 1
    }
}

# ============================================================================
# Main Orchestrator
# ============================================================================


# Handle help
if ($Help) {
    Write-Host "Faria Installation Script"
    Write-Host ""
    Write-Host "Usage: .\install.ps1 [OPTIONS]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -Features LIST    Comma-separated list: idp, chat, all"
    Write-Host "  -InstallDir DIR   Install to DIR (default: $env:USERPROFILE\.faria)"
    Write-Host "  -GPU              Enable GPU support (CUDA)"
    Write-Host "  -WithLLM          Install LLM support for IDP"
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
Write-Host "         DETR model (layout detection), Nemotron model (tables)"
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
        Invoke-InstallIDP -InstallDir $InstallDir -GPU:$GPU -WithLLM:$InstallIDPLLM
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
    Write-Host "  - IDP - OpenCV, Tesseract, MuPDF, ONNX Runtime, DETR, Nemotron"
}
if ($InstallChat) {
    Write-Host "  - Chat - llama.cpp, Qwen 2.5"
}
Write-Host ""
Write-Host "For more information, see: https://github.com/exto360-inc/faria"
Write-Host ""
