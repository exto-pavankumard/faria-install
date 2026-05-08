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

One-liner (pipe to PowerShell):

```powershell
# IDP only
irm https://raw.githubusercontent.com/exto360-inc/faria-install/main/dist/install.ps1 | iex

# Or with flags (download first, then run)
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/exto360-inc/faria-install/main/dist/install.ps1" -OutFile "install.ps1"
.\install.ps1 -Features idp

# Skip Python model export — download pre-built ONNX from HuggingFace
.\install.ps1 -Features idp -System
```

> **Note:** After installation, open a **new PowerShell session** for PATH and environment variable changes (MinGW-w64, TESSDATA_PREFIX, CGO_CFLAGS) to take effect.

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
| OS | macOS 12+, Ubuntu 20.04+, Windows 10+ (build 1809+) |
| RAM | 8 GB (16 GB recommended) |
| Disk | 2 GB free space (4 GB with Chat) |
| Python | 3.12 (for model export only — skip with `--system` / `-System`) |

### Supported Architectures

| Platform | IDP (CGO) | Chat |
|----------|-----------|------|
| macOS | arm64, x86_64 | arm64, x86_64 |
| Linux | x86_64, aarch64 | x86_64, aarch64 |
| Windows | **x86_64 only** | x86_64, arm64 |

> **Windows IDP note:** CGO compilation requires MinGW-w64 pre-built libs, which are x86_64 only in this release. ARM64 Windows (Snapdragon) supports Chat but not IDP.

### Windows Prerequisites

The installer handles these automatically, but knowing what gets installed helps:

| Prerequisite | How installed | Required for |
|---|---|---|
| winget (App Installer) | Pre-installed on Windows 10 1709+ | MSYS2 install |
| MSYS2 | `winget install MSYS2.MSYS2` | CGO toolchain |
| MinGW-w64 gcc | `pacman` via MSYS2 | IDP CGO compilation |
| pkg-config | `pacman` via MSYS2 | Library discovery |

If MSYS2 is already installed at `C:\msys64`, the installer detects it and skips the winget step.

---

## Features

Faria uses a feature-based installation model:

### IDP - Intelligent Document Processing (~630 MB)

Everything needed for document layout detection and table extraction.

| Component | Size | Purpose |
|-----------|------|---------|
| MinGW-w64 toolchain | ~600 MB | CGO compilation (Windows only) |
| OpenCV 4.12.0 | ~25 MB | Image processing |
| Tesseract OCR 5.5.0 | ~30 MB | Text extraction |
| Leptonica | bundled | Image library (with Tesseract) |
| MuPDF 1.24.9 | ~5 MB | PDF rendering (static libs) |
| ONNX Runtime 1.22.0 | ~50 MB | Model inference engine |
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
| `--system` | Download pre-exported ONNX from HuggingFace + system-wide ONNX install. Skips Python entirely. Use for Docker/CGO builds. |
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
| `-GPU` | Enable GPU support (CUDA). Requires CUDA Toolkit 11.8+. |
| `-WithLLM` | Install LLM support for IDP without being prompted |
| `-System` | Download pre-exported ONNX from HuggingFace. Skips Python entirely. Faster first install. |
| `-Help` | Show help message |

**Interactive Mode:** Run without options to be prompted for feature selection.

**LLM Prompt:** When installing IDP without `-WithLLM`, you'll be asked if you want to add LLM support (~500 MB extra).

#### Examples

```powershell
# IDP only (prompts for LLM)
.\install.ps1 -Features idp

# Chat only
.\install.ps1 -Features chat

# Both features
.\install.ps1 -Features "idp,chat"
.\install.ps1 -Features all

# IDP with GPU support (requires CUDA Toolkit 11.8+)
.\install.ps1 -Features idp -GPU

# IDP with LLM support (no prompt)
.\install.ps1 -Features idp -WithLLM

# Fast install — skip Python, download pre-built ONNX models from HuggingFace
.\install.ps1 -Features idp -System

# Custom directory
.\install.ps1 -Features all -InstallDir "D:\faria"

# Interactive mode
.\install.ps1
```

#### Windows: `-System` vs default (Python export)

| | Default | `-System` |
|---|---|---|
| DETR model | Exported via PyTorch locally | Downloaded from HuggingFace |
| Nemotron model | Exported via PyTorch locally | Downloaded from HuggingFace |
| CLIP model | Downloaded from HuggingFace | Downloaded from HuggingFace |
| Python required | Yes (3.12) | No |
| First-run time | Longer (model export) | Faster |

Use `-System` unless you need a locally-exported model variant.

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

- **ONNX Runtime** - Core inference engine
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
- DETR, Nemotron, and CLIP models
- OpenCV, MuPDF dev libs (Windows: `%USERPROFILE%\.faria\lib\`)
- llama-cli and Qwen model (if installed)
- All files in the Faria installation directory

### What Does NOT Get Removed

**macOS / Linux — system packages (remove manually):**
```bash
# macOS
brew uninstall tesseract opencv mupdf

# Ubuntu/Debian
sudo apt remove tesseract-ocr libopencv-dev libmupdf-dev
```

**Windows — installed separately (remove manually):**
- **MSYS2 + MinGW-w64:** `winget uninstall MSYS2.MSYS2` or use Add/Remove Programs
- **Tesseract:** Add/Remove Programs → "Tesseract-OCR"

**Environment variables set by the installer (remove manually):**

On Windows, these are written to the user registry by the installer:
```
TESSDATA_PREFIX       → %USERPROFILE%\.faria\tesseract\tessdata
FARIA_ONNXRUNTIME_PATH → %USERPROFILE%\.faria\lib\onnxruntime\onnxruntime.dll
CGO_CFLAGS            → include paths for OpenCV, MuPDF, Tesseract
CGO_LDFLAGS           → lib paths for OpenCV, MuPDF, Tesseract
PKG_CONFIG_PATH       → C:\msys64\mingw64\lib\pkgconfig
```

Remove them in PowerShell:
```powershell
foreach ($var in @("TESSDATA_PREFIX","FARIA_ONNXRUNTIME_PATH","CGO_CFLAGS","CGO_LDFLAGS")) {
    [Environment]::SetEnvironmentVariable($var, $null, "User")
}
```

On macOS/Linux, remove from your shell profile (`~/.bashrc`, `~/.zshrc`):
```
FARIA_ONNXRUNTIME_PATH
FARIA_CLIP_MODEL_PATH
FARIA_DETR_MODEL_PATH
FARIA_NEMOTRON_MODEL_PATH
FARIA_LLAMA_CLI_PATH
FARIA_SLM_MODEL_PATH
```

---

## Configuration

### Environment Variables (macOS / Linux)

Add to your shell profile (`~/.bashrc`, `~/.zshrc`, or `~/.profile`):

```bash
# IDP components
export FARIA_ONNXRUNTIME_PATH="$HOME/.faria/lib/onnxruntime/libonnxruntime.dylib"
export FARIA_CLIP_MODEL_PATH="$HOME/.faria/models/clip_vision.onnx"
export FARIA_DETR_MODEL_PATH="$HOME/.faria/models/detr_layout_detection.onnx"
export FARIA_NEMOTRON_MODEL_PATH="$HOME/.faria/models/nemotron_table_structure.onnx"

# Chat components (optional)
export FARIA_LLAMA_CLI_PATH="$HOME/.faria/bin/llama-cli"
export FARIA_SLM_MODEL_PATH="$HOME/.faria/models/qwen2.5-0.5b-instruct-q8_0.gguf"
```

**Note:** If using the default `~/.faria/` location, environment variables are optional — Faria will auto-detect the paths.

### Environment Variables (Windows)

The installer sets these automatically in the user registry. They take effect in new PowerShell sessions.

| Variable | Value | Purpose |
|---|---|---|
| `TESSDATA_PREFIX` | `%USERPROFILE%\.faria\tesseract\tessdata` | Tesseract language data |
| `FARIA_ONNXRUNTIME_PATH` | `%USERPROFILE%\.faria\lib\onnxruntime\onnxruntime.dll` | ONNX Runtime DLL |
| `CGO_CFLAGS` | `-I.../opencv/include -I.../mupdf/include -I.../tesseract/include` | CGO compiler includes |
| `CGO_LDFLAGS` | `-L.../opencv/lib -L.../mupdf/lib -L.../tesseract/lib` | CGO linker paths |
| `PKG_CONFIG_PATH` | `C:\msys64\mingw64\lib\pkgconfig` | pkg-config search path |

With `pkg-config` in place, `go build` discovers CGO flags automatically — the `CGO_CFLAGS`/`CGO_LDFLAGS` variables are a fallback for manual builds.

To verify in a new PowerShell session:
```powershell
$env:TESSDATA_PREFIX          # should print the tessdata path
pkg-config --exists opencv4   # should exit 0
pkg-config --exists mupdf     # should exit 0
pkg-config --exists tesseract # should exit 0
```

### Installer Environment Variables

| Variable | Description |
|----------|-------------|
| `FARIA_INSTALL_RAW` | Override the base URL for `curl \| bash` / `iwr \| iex` sub-script downloads (default: `https://raw.githubusercontent.com/exto360-inc/faria-install/main`). Useful for testing forks or private mirrors. |
| `HF_TOKEN` | HuggingFace authentication token. Required if any model repo is gated. Used automatically by `--system` / `-System`. |

### Platform-Specific Library Names

| Platform | Library Name |
|----------|--------------|
| macOS | `libonnxruntime.dylib` |
| Linux | `libonnxruntime.so` |
| Windows | `onnxruntime.dll` |

---

## Directory Structure

### macOS / Linux

After installation:

```
~/.faria/
├── bin/
│   └── llama-cli                          # LLM inference (Chat feature)
├── lib/
│   └── onnxruntime/
│       └── libonnxruntime.{dylib,so}      # ONNX Runtime library
└── models/
    ├── clip_vision.onnx                   # Visual embedding (IDP)
    ├── detr_layout_detection.onnx         # Layout detection (IDP)
    ├── nemotron_table_structure.onnx      # Table structure (IDP)
    └── qwen2.5-0.5b-instruct-q8_0.gguf   # LLM model (Chat)
```

> **Note:** When `--system` is used, ONNX Runtime is installed to `/usr/local` instead of `~/.faria/lib/onnxruntime/`. Models are still placed in `~/.faria/models/`.

### Windows

After a full IDP install:

```
%USERPROFILE%\.faria\
├── bin\
│   ├── mutool.exe                         # MuPDF tool
│   └── llama-cli.exe                      # LLM inference (Chat feature)
├── lib\
│   ├── opencv\
│   │   ├── include\opencv4\               # Headers for CGO
│   │   ├── lib\                           # libopencv_world4120.dll.a (MinGW import lib)
│   │   ├── lib\pkgconfig\opencv4.pc
│   │   └── bin\libopencv_world4120.dll    # Runtime DLL
│   ├── mupdf\
│   │   ├── include\mupdf\                 # Headers for CGO
│   │   ├── lib\libmupdf.a                 # Static lib
│   │   ├── lib\libmupdf-third.a           # Bundled deps (zlib, jpeg, etc.)
│   │   └── lib\pkgconfig\mupdf.pc
│   └── onnxruntime\
│       ├── include\                       # ONNX C API headers
│       └── onnxruntime.dll
├── tesseract\                             # UB-Mannheim install target
│   ├── include\tesseract\                 # Headers for CGO
│   ├── include\leptonica\
│   ├── lib\pkgconfig\tesseract.pc
│   ├── lib\pkgconfig\lept.pc
│   └── tessdata\                          # TESSDATA_PREFIX points here
└── models\
    ├── clip_vision.onnx
    ├── detr_layout_detection.onnx
    ├── nemotron_table_structure.onnx
    └── qwen2.5-0.5b-instruct-q8_0.gguf   # LLM model (Chat)
```

pkg-config descriptors are also copied to `C:\msys64\mingw64\lib\pkgconfig\` so MinGW's `go build` can discover all libraries automatically.

---

## Troubleshooting

For detailed troubleshooting, see [TROUBLESHOOTING.md](TROUBLESHOOTING.md).

---

## Need Help?

- **Troubleshooting:** [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
- **Installer Issues:** https://github.com/exto360-inc/faria-install/issues
- **Faria Issues:** https://github.com/exto360-inc/faria/issues
