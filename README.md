# Faria Installer

Dependency installer for [Faria](https://github.com/exto360-inc/faria), a document processing library with ML-powered layout detection and table extraction.

## Quick Start

### macOS / Linux

```bash
# IDP only (Document Processing)
curl -fsSL https://raw.githubusercontent.com/exto360-inc/faria-install/main/install.sh | bash -s -- --features idp

# Chat only (Conversational AI)
curl -fsSL https://raw.githubusercontent.com/exto360-inc/faria-install/main/install.sh | bash -s -- --features chat

# Both features
curl -fsSL https://raw.githubusercontent.com/exto360-inc/faria-install/main/install.sh | bash -s -- --features all

# Interactive mode (prompts for options)
curl -fsSL https://raw.githubusercontent.com/exto360-inc/faria-install/main/install.sh | bash
```

### Windows (PowerShell)

```powershell
# One-liner (IDP, interactive)
irm https://raw.githubusercontent.com/exto360-inc/faria-install/main/dist/install.ps1 | iex

# Or download and run with flags
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/exto360-inc/faria-install/main/dist/install.ps1" -OutFile "install.ps1"
.\install.ps1 -Features idp

# Fast install — skip Python, download pre-built ONNX from HuggingFace
.\install.ps1 -Features idp -System
```

> Open a **new PowerShell session** after installation for PATH and env var changes to take effect.

### Clone and Install

```bash
git clone https://github.com/exto360-inc/faria-install.git
cd faria-install
./install.sh --features idp
```

## System Requirements

| | Requirement |
|---|---|
| OS | macOS 12+, Ubuntu 20.04+, Windows 10+ |
| RAM | 8 GB (16 GB recommended) |
| Disk | 2 GB (4 GB with Chat) |
| Python | 3.12 (for model export) |

### Supported Architectures

| Platform | IDP (CGO) | Chat |
|---|---|---|
| macOS | arm64, x86_64 | arm64, x86_64 |
| Linux | x86_64, aarch64 | x86_64, aarch64 |
| Windows | **x86_64 only** | x86_64, arm64 |

## Features

### IDP - Intelligent Document Processing (~630 MB)

| Component | Size | Description |
|---|---|---|
| OpenCV | - | Image processing (system install) |
| Tesseract OCR | 30 MB | Text extraction (system install) |
| Leptonica | - | Image library (system install) |
| MuPDF | - | PDF rendering (system install) |
| ONNX Runtime | 50 MB | Model inference engine |
| CLIP Model | ~100 MB | Visual embedding (Qdrant/clip-ViT-B-32) |
| DETR Model | 350 MB | Document layout detection |
| Nemotron Model | 200 MB | Table structure recognition |

### Chat - Conversational AI (~535 MB)

| Component | Size | Description |
|---|---|---|
| llama.cpp | 5 MB | LLM inference engine |
| Qwen 2.5 | 530 MB | Language model |

## Installation Options

### macOS / Linux

```
--features LIST       Comma-separated list of features (idp, chat, all)
--install-dir PATH    Installation directory (default: ~/.faria)
--gpu                 Enable CUDA support (Linux only)
--system              System-wide ONNX install + HF direct model download (Docker/CGO)
--help                Show help message
```

### Windows (PowerShell)

```
-Features LIST        Comma-separated list of features (idp, chat, all)
-InstallDir PATH      Installation directory (default: %USERPROFILE%\.faria)
-GPU                  Enable GPU support (CUDA — requires CUDA Toolkit 11.8+)
-WithLLM              Install LLM support for IDP without being prompted
-System               Download pre-built ONNX from HuggingFace (skip Python)
-Help                 Show help message
```

### Examples

```bash
# IDP with GPU support (Linux)
./install.sh --features idp --gpu

# Custom installation directory
./install.sh --features all --install-dir /opt/faria

# System-wide install for Docker/CGO builds (no Python required)
./install.sh --features idp --system
```

```powershell
# Windows: IDP with GPU
.\install.ps1 -Features idp -GPU

# Windows: fast install (no Python)
.\install.ps1 -Features idp -System

# Windows: custom directory
.\install.ps1 -Features all -InstallDir "D:\faria"
```

## Directory Structure

**macOS / Linux** (`~/.faria/`):

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

**Windows** (`%USERPROFILE%\.faria\`):

```
.faria\
├── bin\mutool.exe / llama-cli.exe
├── lib\opencv\       — DLL + headers + opencv4.pc
├── lib\mupdf\        — static libs + headers + mupdf.pc
├── lib\onnxruntime\  — onnxruntime.dll
├── tesseract\        — UB-Mannheim install + tessdata + .pc files
└── models\           — clip_vision / detr / nemotron / qwen .onnx/.gguf
```

See [INSTALLATION.md](INSTALLATION.md) for the full Windows directory layout.

## Verification

```bash
./scripts/verify.sh
```

## Usage

After installation, use the Faria Go module:

```bash
go get github.com/exto360-inc/faria
```

```go
package main

import "github.com/exto360-inc/faria"

func main() {
    config := faria.DefaultConfig()
    client, err := faria.New(config)
    if err != nil {
        panic(err)
    }
    defer client.Close()

    // Process documents...
}
```

## Uninstallation

```bash
# macOS / Linux
./scripts/uninstall.sh
```

```powershell
# Windows
.\scripts\uninstall.ps1
```

Or manually remove `~/.faria` (macOS/Linux) or `%USERPROFILE%\.faria` (Windows).

See [INSTALLATION.md](INSTALLATION.md) for env vars and system packages that need manual removal.

## Documentation

- [INSTALLATION.md](INSTALLATION.md) - Manual installation, GPU configuration, environment variables
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Common errors and solutions (Python, CGO, Tesseract, OpenCV, MuPDF, ONNX Runtime)

## License

Copyright (c) 2024 Exto360 Inc. All rights reserved. See [LICENSE](LICENSE).
