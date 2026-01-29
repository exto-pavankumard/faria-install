#
# Faria ML Models Installation Script for Windows
# Exports and installs DETR (layout detection) and Nemotron (table structure) models
#
# Usage: .\install-models.ps1 [-InstallDir DIR]
#
# Prerequisites:
#   - Python 3.8+
#   - Git with Git LFS
#

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
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
# The repo root is the parent of scripts/
$RepoDir = Split-Path -Parent $ScriptDir

Write-Host "Detecting system..." -ForegroundColor Yellow
Write-Host "  OS: Windows"
Write-Host "  Repository: $RepoDir"
Write-Host ""

# Check prerequisites
Write-Host "Checking prerequisites..." -ForegroundColor Yellow

# Check Python (requires 3.12.x for onnxruntime compatibility)
$PythonCmd = & "$ScriptDir\setup-python.ps1"

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
            & python $DETRExportScript --output $DETRModelPath
            Pop-Location

            if (Test-Path $DETRModelPath) {
                $DETRSize = [math]::Round((Get-Item $DETRModelPath).Length / 1MB, 1)
                Write-Host "  DETR model installed: $DETRModelPath ($DETRSize MB)" -ForegroundColor Green
            } else {
                Write-Host "Error: DETR ONNX file not found after export" -ForegroundColor Red
                Write-Host "  Expected output: $DETRModelPath"
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

            & python $NemotronExportScript --output $NemotronModelPath
            Pop-Location

            if (Test-Path $NemotronModelPath) {
                $NemotronSize = [math]::Round((Get-Item $NemotronModelPath).Length / 1MB, 1)
                Write-Host "  Nemotron model installed: $NemotronModelPath ($NemotronSize MB)" -ForegroundColor Green
            } else {
                Write-Host "Error: Nemotron ONNX file not found after export" -ForegroundColor Red
                Write-Host "  Expected output: $NemotronModelPath"
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
