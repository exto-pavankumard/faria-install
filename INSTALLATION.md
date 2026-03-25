# Faria Installation Guide

Complete guide for installing Faria and its dependencies on macOS, Linux, and Windows.

## Table of Contents

- [Quick Start](#quick-start)
- [System Requirements](#system-requirements)
- [Features](#features)
- [Installation Options](#installation-options)
- [Verification](#verification)
- [Uninstallation](#uninstallation)
- [Configuration](#configuration)
- [Directory Structure](#directory-structure)
- [Troubleshooting](#troubleshooting)

---

## Quick Start

### macOS / Linux

```bash
# IDP only (Document Processing)
curl -fsSL https://raw.githubusercontent.com/exto360-inc/faria-install/main/dist/install.sh | bash -s -- --features idp

# Chat only (Conversational AI)
curl -fsSL https://raw.githubusercontent.com/exto360-inc/faria-install/main/dist/install.sh | bash -s -- --features chat

# Both features
curl -fsSL https://raw.githubusercontent.com/exto360-inc/faria-install/main/dist/install.sh | bash -s -- --features all

# Interactive installation (prompts for options)
curl -fsSL https://raw.githubusercontent.com/exto360-inc/faria-install/main/dist/install.sh | bash
```

### Windows (PowerShell)

```powershell
# Download and run the installer
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/exto360-inc/faria-install/main/dist/install.ps1" -OutFile "install.ps1"

# IDP only (Document Processing)
.\install.ps1 -Features idp

# Chat only (Conversational AI)
.\install.ps1 -Features chat

# Both features
.\install.ps1 -Features all

# Interactive installation (prompts for options)
.\install.ps1
```

### Clone and Install

```bash
git clone https://github.com/exto360-inc/faria-install.git
cd faria-install
./install.sh --features idp
```

---

## System Requirements

### Minimum Requirements

| Component | Requirement |
|-----------|-------------|
| OS | macOS 12+, Ubuntu 20.04+, Windows 10+ |
| RAM | 8 GB (16 GB recommended) |
| Disk | 2 GB free space (4 GB with Chat) |
| Python | 3.12 (for model export only) |

### Supported Architectures

| Platform | Architectures |
|----------|---------------|
| macOS | arm64 (Apple Silicon), x86_64 (Intel) |
| Linux | x86_64, aarch64 |
| Windows | x64, arm64 |

---

## Features

Faria uses a feature-based installation model:

### IDP - Intelligent Document Processing (~630 MB)

Everything needed for document layout detection and table extraction.

| Component | Size | Purpose |
|-----------|------|---------|
| OpenCV | - | Image processing (system install) |
| Tesseract OCR | ~30 MB | Text extraction (system install) |
| Leptonica | - | Image library (system install) |
| MuPDF | - | PDF rendering (system install) |
| ONNX Runtime | ~50 MB | Model inference engine |
| CLIP Model | ~100 MB | Visual embedding (Qdrant/clip-ViT-B-32) |
| DETR Model | ~350 MB | Document layout detection |
| Nemotron Model | ~200 MB | Table structure detection |

**Optional:** LLM support (~500 MB extra) for advanced document understanding. You will be prompted during installation.

### Chat - Conversational AI (~535 MB)

LLM-powered features like cross-page table merging.

| Component | Size | Purpose |
|-----------|------|---------|
| llama.cpp | ~5 MB | LLM inference engine |
| Qwen 2.5 | ~530 MB | Language model |

---

## Installation Options

### macOS / Linux (install.sh)

```bash
./install.sh [OPTIONS]
```

| Option | Description |
|--------|-------------|
| `--features LIST` | Comma-separated list: `idp`, `chat`, `all` |
| `--install-dir DIR` | Installation directory (default: `~/.faria`) |
| `--gpu` | Enable GPU support (CUDA on Linux) |
| `--system` | System-wide ONNX Runtime install + HF direct model download (no Python required; for Docker/CGO builds) |
| `--help`, `-h` | Show help message |

**Interactive Mode:** Run without options to be prompted for feature selection.

**LLM Prompt:** When installing IDP, you'll be asked if you want to add LLM support for advanced document understanding (~500 MB extra).

#### Examples

```bash
# IDP only (prompts for optional LLM support)
./install.sh --features idp

# Chat only
./install.sh --features chat

# Both features
./install.sh --features idp,chat
./install.sh --features all

# IDP with GPU support (Linux only)
./install.sh --features idp --gpu

# System-wide install for Docker/CGO (no Python required)
./install.sh --features idp --system

# Custom directory
./install.sh --features all --install-dir /opt/faria

# Interactive mode
./install.sh
```

### Windows (install.ps1)

```powershell
.\install.ps1 [OPTIONS]
```

| Option | Description |
|--------|-------------|
| `-Features LIST` | Comma-separated list: `idp`, `chat`, `all` |
| `-InstallDir DIR` | Installation directory (default: `%USERPROFILE%\.faria`) |
| `-GPU` | Enable GPU support (CUDA) |
| `-WithLLM` | Install LLM support for IDP (advanced document understanding) |
| `-Help` | Show help message |

**Interactive Mode:** Run without options to be prompted for feature selection.

**LLM Prompt:** When installing IDP, you'll be asked if you want to add LLM support for advanced document understanding (~500 MB extra).

#### Examples

```powershell
# IDP only (prompts for optional LLM support)
.\install.ps1 -Features idp

# Chat only
.\install.ps1 -Features chat

# Both features
.\install.ps1 -Features "idp,chat"
.\install.ps1 -Features all

# IDP with GPU support
.\install.ps1 -Features idp -GPU

# IDP with LLM support (no prompt)
.\install.ps1 -Features idp -WithLLM

# Custom directory
.\install.ps1 -Features all -InstallDir "D:\faria"

# Interactive mode
.\install.ps1
```

---

## Verification

Verify your installation is complete and working.

### macOS / Linux

```bash
./scripts/verify.sh [OPTIONS]
```

| Option | Description |
|--------|-------------|
| `--install-dir DIR` | Check installation in DIR (default: `~/.faria`) |
| `--help`, `-h` | Show help message |

### Windows

```powershell
.\scripts\verify.ps1 [OPTIONS]
```

| Option | Description |
|--------|-------------|
| `-InstallDir DIR` | Check installation in DIR (default: `%USERPROFILE%\.faria`) |
| `-Help` | Show help message |

### What Gets Checked

- **ONNX Runtime** - Core inference engine (user install or system install)
- **CLIP Model** - Visual embedding model
- **DETR Model** - Document layout detection
- **Nemotron Model** - Table structure detection
- **IDP Dependencies** - OpenCV, Tesseract, Leptonica, MuPDF
- **LLM Components** - llama-cli and Qwen model (optional)

---

## Uninstallation

Remove all Faria-installed files.

### macOS / Linux

```bash
./scripts/uninstall.sh [OPTIONS]
```

| Option | Description |
|--------|-------------|
| `--install-dir DIR` | Uninstall from DIR (default: `~/.faria`) |
| `--force`, `-f` | Skip confirmation prompt |
| `--help`, `-h` | Show help message |

### Windows

```powershell
.\scripts\uninstall.ps1 [OPTIONS]
```

| Option | Description |
|--------|-------------|
| `-InstallDir DIR` | Uninstall from DIR (default: `%USERPROFILE%\.faria`) |
| `-Force` | Skip confirmation prompt |
| `-Help` | Show help message |

### What Gets Removed

- ONNX Runtime library
- DETR and Nemotron models
- llama-cli and Qwen model (if installed)
- All files in the Faria installation directory

### What Does NOT Get Removed

- **System-installed Tesseract OCR** - Remove manually:
  ```bash
  # macOS
  brew uninstall tesseract

  # Ubuntu/Debian
  sudo apt remove tesseract-ocr

  # Windows
  winget uninstall tesseract
  ```

- **Environment variables** - Remove from your shell profile:
  - `FARIA_ONNXRUNTIME_PATH`
  - `FARIA_CLIP_MODEL_PATH`
  - `FARIA_DETR_MODEL_PATH`
  - `FARIA_NEMOTRON_MODEL_PATH`
  - `FARIA_LLAMA_CLI_PATH`
  - `FARIA_SLM_MODEL_PATH`

---

## Configuration

### Environment Variables

Add to your shell profile (`~/.bashrc`, `~/.zshrc`, or `~/.profile`):

```bash
# IDP components
export FARIA_ONNXRUNTIME_PATH="$HOME/.faria/lib/onnxruntime/libonnxruntime.dylib"
export FARIA_CLIP_MODEL_PATH="$HOME/.faria/models/clip_visual.onnx"
export FARIA_DETR_MODEL_PATH="$HOME/.faria/models/detr_layout_detection.onnx"
export FARIA_NEMOTRON_MODEL_PATH="$HOME/.faria/models/nemotron_table_structure.onnx"

# Chat components (optional)
export FARIA_LLAMA_CLI_PATH="$HOME/.faria/bin/llama-cli"
export FARIA_SLM_MODEL_PATH="$HOME/.faria/models/qwen2.5-0.5b-instruct-q8_0.gguf"
```

**Note:** If using the default `~/.faria/` location, environment variables are optional - Faria will auto-detect the paths.

### Installer Environment Variables

| Variable | Description |
|----------|-------------|
| `FARIA_INSTALL_RAW` | Override the base URL used by `curl \| bash` to download sub-scripts (default: `https://raw.githubusercontent.com/exto360-inc/faria-install/main`). Useful for testing forks or private mirrors. |
| `HF_TOKEN` | HuggingFace authentication token. Required if any model repo is gated. Used automatically by `--system` model download. |

### Platform-Specific Library Names

| Platform | Library Name |
|----------|--------------|
| macOS | `libonnxruntime.dylib` |
| Linux | `libonnxruntime.so` |
| Windows | `onnxruntime.dll` |

---

## Directory Structure

After installation:

```
~/.faria/
├── bin/
│   └── llama-cli              # LLM inference (Chat/LLM feature)
├── lib/
│   └── onnxruntime/
│       └── libonnxruntime.dylib  # ONNX Runtime library
└── models/
    ├── clip_visual.onnx                 # Visual embedding (IDP)
    ├── detr_layout_detection.onnx      # Layout detection (IDP)
    ├── nemotron_table_structure.onnx   # Table structure (IDP)
    └── qwen2.5-0.5b-instruct-q8_0.gguf # LLM model (Chat/LLM)
```

> **Note:** When `--system` is used, ONNX Runtime is installed to `/usr/local` instead of `~/.faria/lib/onnxruntime/`. Models are still placed in `~/.faria/models/`.

---

## Troubleshooting

For detailed troubleshooting, see [TROUBLESHOOTING.md](TROUBLESHOOTING.md).

---

## Need Help?

- **Troubleshooting:** [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
- **Installer Issues:** https://github.com/exto360-inc/faria-install/issues
- **Faria Issues:** https://github.com/exto360-inc/faria/issues
