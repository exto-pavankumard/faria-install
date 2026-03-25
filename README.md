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
# Download the installer
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/exto360-inc/faria-install/main/install.ps1" -OutFile "install.ps1"

# Basic installation (without LLM)
.\install.ps1 -NoLLM

# Full installation (with LLM)
.\install.ps1 -WithLLM
```

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

| Platform | Architectures |
|---|---|
| macOS | arm64 (Apple Silicon), x86_64 (Intel) |
| Linux | x86_64, aarch64 |
| Windows | x64, arm64 |

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
-InstallDir PATH      Installation directory (default: %USERPROFILE%\.faria)
-GPU                  Enable GPU support (CUDA)
-WithLLM              Install LLM components
-NoLLM                Skip LLM components
-SkipTesseract        Skip Tesseract if already installed
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

# IDP only (backward compatible)
./install.sh --no-llm
```

## Directory Structure

```
~/.faria/
├── bin/
│   └── llama-cli                         # LLM inference (Chat feature)
├── lib/
│   └── onnxruntime/
│       └── libonnxruntime.dylib          # ONNX Runtime library
└── models/
    ├── clip_visual.onnx                  # Visual embedding (IDP)
    ├── detr_layout_detection.onnx        # Layout detection (IDP)
    ├── nemotron_table_structure.onnx     # Table structure (IDP)
    └── qwen2.5-0.5b-instruct-q8_0.gguf   # LLM model (Chat)
```

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
./scripts/uninstall.sh
```

Or manually:

```bash
rm -rf ~/.faria
```

## Documentation

- [INSTALLATION.md](INSTALLATION.md) - Manual installation, GPU configuration, environment variables
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Common errors and solutions (Python, CGO, Tesseract, OpenCV, MuPDF, ONNX Runtime)

## License

Copyright (c) 2024 Exto360 Inc. All rights reserved. See [LICENSE](LICENSE).
