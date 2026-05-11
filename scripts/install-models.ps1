#
# Faria ML Models Installation Script for Windows
# Installs DETR, Nemotron, and CLIP ONNX models.
#
# Usage: .\install-models.ps1 [-InstallDir DIR] [-System]
#
# -System: download pre-exported ONNX files from HuggingFace instead of
#          running local Python export scripts.
#

param(
    [string]$InstallDir = "$env:USERPROFILE\.faria",
    [switch]$System,
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
    Write-Host "  -System           Download pre-exported ONNX from HuggingFace (skip Python)"
    Write-Host "  -SkipDETR         Skip DETR model installation"
    Write-Host "  -SkipNemotron     Skip Nemotron model installation"
    Write-Host "  -KeepVenv         Keep Python virtual environment after installation"
    Write-Host "  -Help             Show this help message"
    exit 0
}

if (-not (Get-Command 'Set-UserEnv' -ErrorAction SilentlyContinue)) {
    . (Join-Path $PSScriptRoot '_common.ps1')
}

Write-Host "========================================" -ForegroundColor Blue
Write-Host "  Faria ML Models Installation" -ForegroundColor Blue
Write-Host "========================================" -ForegroundColor Blue
Write-Host ""

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoDir   = Split-Path -Parent $ScriptDir

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
    $PythonCmd = & "$ScriptDir\setup-python.ps1"

    if (-not $PythonCmd -or -not (Get-Command $PythonCmd -ErrorAction SilentlyContinue)) {
        Write-Host "Error: Python 3.12 setup failed." -ForegroundColor Red
        exit 1
    }

    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Host "Error: Git not found. Please install Git." -ForegroundColor Red
        exit 1
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
            exit 1
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
                    exit 1
                }
                Push-Location $WorkDir
                & python $DETRExportScript --output $DETRModelPath
                Pop-Location

                if (-not (Test-Path $DETRModelPath)) {
                    Write-Host "Error: DETR ONNX not produced." -ForegroundColor Red
                    exit 1
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
                    exit 1
                }
                & python $NemotronExportScript --output $NemotronModelPath
                Pop-Location

                if (-not (Test-Path $NemotronModelPath)) {
                    Write-Host "Error: Nemotron ONNX not produced." -ForegroundColor Red
                    exit 1
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

if (-not $allOk) { exit 1 }

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
