# Faria Installation Guide

Complete guide for installing Faria and its dependencies on macOS, Linux, and Windows.

## Table of Contents

- [Quick Start](#quick-start)
- [System Requirements](#system-requirements)
- [What Gets Installed](#what-gets-installed)
- [Installation Options](#installation-options)
- [Manual Installation](#manual-installation)
- [GPU Support](#gpu-support)
- [Configuration](#configuration)
- [Verification](#verification)
- [Troubleshooting](#troubleshooting)
- [Uninstallation](#uninstallation)

---

## Quick Start

### macOS / Linux

```bash
# One-liner installation (without LLM)
curl -fsSL https://raw.githubusercontent.com/exto360-inc/faria-install/main/install.sh | bash -s -- --no-llm

# Or with LLM support for cross-page table merging
curl -fsSL https://raw.githubusercontent.com/exto360-inc/faria-install/main/install.sh | bash -s -- --with-llm

# Interactive installation (will prompt for options)
curl -fsSL https://raw.githubusercontent.com/exto360-inc/faria-install/main/install.sh | bash
```

### Windows (PowerShell)

```powershell
# Download and run the installer
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/exto360-inc/faria-install/main/install.ps1" -OutFile "install.ps1"

# Run the installer (without LLM)
.\install.ps1 -NoLLM

# Or with LLM support
.\install.ps1 -WithLLM
```

### Alternative: Clone the installer repository

```bash
git clone https://github.com/exto360-inc/faria-install.git
cd faria-install
./install.sh --no-llm
```

---

## System Requirements

### Minimum Requirements

| Component | Requirement |
|-----------|-------------|
| OS | macOS 12+, Ubuntu 20.04+, Windows 10+ |
| RAM | 8 GB (16 GB recommended) |
| Disk | 2 GB free space (4 GB with LLM) |
| Python | 3.12 (for model export only) |

### Supported Architectures

| Platform | Architectures |
|----------|---------------|
| macOS | arm64 (Apple Silicon), x86_64 (Intel) |
| Linux | x86_64, aarch64 |
| Windows | x64, arm64 |

---

## What Gets Installed

### Required Components (~630 MB)

| Component | Size | Purpose |
|-----------|------|---------|
| ONNX Runtime | ~50 MB | Model inference engine |
| DETR Model | ~350 MB | Document layout detection |
| Nemotron Model | ~200 MB | Table structure detection |
| Tesseract OCR | ~30 MB | Text extraction |

### Optional Components (~535 MB)

| Component | Size | Purpose |
|-----------|------|---------|
| llama.cpp | ~5 MB | LLM inference engine |
| Qwen 2.5 | ~530 MB | Cross-page table merging |

---

## Installation Options

```bash
curl -fsSL https://raw.githubusercontent.com/exto360-inc/faria-install/main/install.sh | bash -s -- [OPTIONS]

Options:
  --install-dir PATH    Custom installation directory (default: ~/.faria)
  --with-llm            Install LLM components without prompting
  --no-llm              Skip LLM components without prompting
  --gpu                 Enable GPU support (CUDA on Linux/Windows)
  --skip-tesseract      Skip Tesseract if already installed system-wide
  --help                Show help message
```

### Examples

```bash
# Basic installation (interactive - will prompt for LLM)
curl -fsSL https://raw.githubusercontent.com/exto360-inc/faria-install/main/install.sh | bash

# Full installation with GPU support
curl -fsSL https://raw.githubusercontent.com/exto360-inc/faria-install/main/install.sh | bash -s -- --with-llm --gpu

# Minimal installation for table extraction only
curl -fsSL https://raw.githubusercontent.com/exto360-inc/faria-install/main/install.sh | bash -s -- --no-llm

# Custom directory (clone method)
git clone https://github.com/exto360-inc/faria-install.git
cd faria-install
./install.sh --install-dir /opt/faria --with-llm
```

---

## Manual Installation

If you prefer manual installation or the automatic script fails:

### 1. Install ONNX Runtime

**IMPORTANT:** On macOS, do NOT use Homebrew - the Homebrew version lacks CoreML/Neural Engine support.

**macOS (with CoreML support):**
```bash
# Download from GitHub releases
VERSION="1.20.1"
ARCH=$(uname -m)  # arm64 or x86_64

curl -L -o onnxruntime.tgz \
  "https://github.com/microsoft/onnxruntime/releases/download/v${VERSION}/onnxruntime-osx-${ARCH}-${VERSION}.tgz"

mkdir -p ~/.faria/lib/onnxruntime
tar -xzf onnxruntime.tgz -C ~/.faria/lib/onnxruntime --strip-components=1
rm onnxruntime.tgz
```

**Linux:**
```bash
VERSION="1.20.1"
curl -L -o onnxruntime.tgz \
  "https://github.com/microsoft/onnxruntime/releases/download/v${VERSION}/onnxruntime-linux-x64-${VERSION}.tgz"

mkdir -p ~/.faria/lib/onnxruntime
tar -xzf onnxruntime.tgz -C ~/.faria/lib/onnxruntime --strip-components=1
rm onnxruntime.tgz
```

**Windows (PowerShell):**
```powershell
$VERSION = "1.20.1"
Invoke-WebRequest -Uri "https://github.com/microsoft/onnxruntime/releases/download/v$VERSION/onnxruntime-win-x64-$VERSION.zip" -OutFile onnxruntime.zip

New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.faria\lib\onnxruntime"
Expand-Archive -Path onnxruntime.zip -DestinationPath "$env:USERPROFILE\.faria\lib\onnxruntime" -Force
Remove-Item onnxruntime.zip
```

### 2. Install Tesseract OCR

**macOS:**
```bash
brew install tesseract leptonica
```

**Ubuntu/Debian:**
```bash
sudo apt update
sudo apt install tesseract-ocr libtesseract-dev libleptonica-dev
```

**Fedora/RHEL:**
```bash
sudo dnf install tesseract tesseract-devel leptonica-devel
```

**Arch Linux:**
```bash
sudo pacman -S tesseract leptonica
```

**Windows:**
Download installer from: https://github.com/UB-Mannheim/tesseract/wiki

### 3. Export ML Models

For manual model export, clone the installer repository and run the export scripts:

```bash
git clone https://github.com/exto360-inc/faria-install.git
cd faria-install

# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install transformers torch onnx onnxruntime

# Export DETR model
python models/export_detr_layout_onnx.py
mkdir -p ~/.faria/models
mv models/detr_layout_detection.onnx ~/.faria/models/

# For Nemotron, you also need Git LFS
git lfs install
git clone https://huggingface.co/nvidia/nemotron-table-structure-v1 /tmp/nemotron
cd /tmp/nemotron && pip install -e . && cd -
python models/export_nemotron_onnx.py
mv models/nemotron_table_structure.onnx ~/.faria/models/

# Cleanup
deactivate
rm -rf venv
```

### 4. Install LLM (Optional)

```bash
git clone https://github.com/exto360-inc/faria-install.git
cd faria-install
./scripts/install-slm.sh
```

---

## GPU Support

### macOS (Apple Silicon)

GPU acceleration via CoreML/Neural Engine is **automatic** when using the official ONNX Runtime release (not Homebrew). No additional configuration is required.

### Linux / Windows (NVIDIA CUDA)

```bash
curl -fsSL https://raw.githubusercontent.com/exto360-inc/faria-install/main/install.sh | bash -s -- --gpu --with-llm
```

**Requirements:**
- NVIDIA GPU with CUDA support
- CUDA Toolkit 11.8 or 12.x
- cuDNN 8.x

The installer will download the CUDA-enabled ONNX Runtime automatically.

---

## Configuration

### Environment Variables

Add to your shell profile (`~/.bashrc`, `~/.zshrc`, or `~/.profile`):

```bash
# Required
export FARIA_ONNXRUNTIME_PATH="$HOME/.faria/lib/onnxruntime/libonnxruntime.dylib"
export FARIA_DETR_MODEL_PATH="$HOME/.faria/models/detr_layout_detection.onnx"
export FARIA_NEMOTRON_MODEL_PATH="$HOME/.faria/models/nemotron_table_structure.onnx"

# Optional (LLM)
export FARIA_LLAMA_CLI_PATH="$HOME/.faria/bin/llama-cli"
export FARIA_SLM_MODEL_PATH="$HOME/.faria/models/qwen2.5-0.5b-instruct-q8_0.gguf"
```

**Note:** If using the default `~/.faria/` location, environment variables are optional - Faria will auto-detect the paths.

### In-Code Configuration

```go
config := faria.DefaultConfig()

// Paths are auto-detected, but can be overridden:
config.Runtime.ONNXLibraryPath = "/custom/path/libonnxruntime.dylib"

// Enable LLM-based cross-page merging
config.Document.EnableAutoMerger = true
config.Document.SLMConfig = faria.DefaultSLMConfig()
```

### Platform-Specific Library Names

| Platform | Library Name |
|----------|--------------|
| macOS | `libonnxruntime.dylib` |
| Linux | `libonnxruntime.so` |
| Windows | `onnxruntime.dll` |

---

## Verification

After installation, verify everything is set up correctly:

```bash
git clone https://github.com/exto360-inc/faria-install.git
cd faria-install
./scripts/verify.sh
```

Expected output:
```
========================================
  Faria Installation Verification
========================================

Checking components...

  ONNX Runtime:  ✓ Found (50 MB)
  DETR Model:    ✓ Found (347 MB)
  Nemotron:      ✓ Found (198 MB)
  Tesseract:     ✓ Found (5.3.0)
  LLM:           ✓ Found (optional)

========================================
  All required components installed!
========================================
```

---

## Troubleshooting

### "ONNX Runtime library not found"

```bash
# Check if file exists
ls -la ~/.faria/lib/onnxruntime/

# Set environment variable explicitly
export FARIA_ONNXRUNTIME_PATH="$HOME/.faria/lib/onnxruntime/libonnxruntime.dylib"
```

### "Model file not found"

```bash
# Verify models exist
ls -la ~/.faria/models/

# Re-run model installation
git clone https://github.com/exto360-inc/faria-install.git
cd faria-install
./scripts/install-models.sh
```

### "Python not found" during model export

```bash
# macOS
brew install python@3.11

# Ubuntu/Debian
sudo apt install python3 python3-venv python3-pip

# Verify version
python3 --version  # Should be 3.8+
```

### "Git LFS not installed" for Nemotron

```bash
# macOS
brew install git-lfs

# Ubuntu/Debian
sudo apt install git-lfs

# Initialize
git lfs install
```

### CoreML not working on macOS

Ensure you downloaded ONNX Runtime from GitHub releases, NOT Homebrew:

```bash
# Wrong (no CoreML)
brew install onnxruntime

# Correct (with CoreML) - use the installer
curl -fsSL https://raw.githubusercontent.com/exto360-inc/faria-install/main/install.sh | bash -s -- --no-llm
```

### Slow performance

1. **Ensure ONNX Runtime is using GPU/Neural Engine:**
   - macOS: CoreML should be automatic with official release
   - Linux/Windows: Use `--gpu` flag during installation

2. **Increase worker count:**
   ```go
   config.Document.WorkerCount = 8
   ```

3. **For LLM, increase GPU layers:**
   ```go
   config.Document.SLMConfig.GPULayers = 99
   ```

### Model export fails with "out of memory"

The model export process requires significant RAM. Try:

1. Close other applications
2. Use a machine with more RAM (16GB recommended)
3. Export models one at a time:
   ```bash
   git clone https://github.com/exto360-inc/faria-install.git
   cd faria-install
   ./scripts/install-models.sh --skip-nemotron  # DETR only
   ./scripts/install-models.sh --skip-detr      # Nemotron only
   ```

---

## Uninstallation

```bash
# Using the installer repo
git clone https://github.com/exto360-inc/faria-install.git
cd faria-install
./scripts/uninstall.sh

# Or manually
rm -rf ~/.faria
```

To also remove environment variables, edit your shell profile and remove the `FARIA_*` exports.

**Note:** System-installed Tesseract OCR is NOT removed by the uninstall script. To remove Tesseract:

```bash
# macOS
brew uninstall tesseract

# Ubuntu/Debian
sudo apt remove tesseract-ocr

# Windows
# Use Control Panel or: winget uninstall tesseract
```

---

## Directory Structure After Installation

```
~/.faria/
├── bin/
│   └── llama-cli              # LLM inference (optional)
├── lib/
│   └── onnxruntime/
│       └── libonnxruntime.dylib  # ONNX Runtime library
└── models/
    ├── detr_layout_detection.onnx      # Layout detection (~350 MB)
    ├── nemotron_table_structure.onnx   # Table structure (~200 MB)
    └── qwen2.5-0.5b-instruct-q8_0.gguf # LLM model (~530 MB, optional)
```

---

## Need Help?

- **Installer Issues:** https://github.com/exto360-inc/faria-install/issues
- **Faria Issues:** https://github.com/exto360-inc/faria/issues
