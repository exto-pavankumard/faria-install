#
# Faria Python Setup Script for Windows
# Ensures Python 3.12.x is available (required for onnxruntime compatibility)
#
# Usage: $PythonCmd = & .\setup-python.ps1
#   Returns the path to a compatible Python interpreter
#

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
