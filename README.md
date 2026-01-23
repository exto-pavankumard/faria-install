# Faria Installer

Public installer for [Faria](https://github.com/exto360-inc/faria) dependencies. This repository allows users to install all required ML models and runtime dependencies without needing access to the main Faria repository.

## Quick Install

### macOS / Linux

```bash
# Basic installation (without LLM)
curl -fsSL https://raw.githubusercontent.com/exto360-inc/faria-install/main/install.sh | bash -s -- --no-llm

# Full installation (with LLM for cross-page table merging)
curl -fsSL https://raw.githubusercontent.com/exto360-inc/faria-install/main/install.sh | bash -s -- --with-llm

# Interactive installation (will prompt for options)
curl -fsSL https://raw.githubusercontent.com/exto360-inc/faria-install/main/install.sh | bash
```

### Windows (PowerShell)

```powershell
# Download and run
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/exto360-inc/faria-install/main/install.ps1" -OutFile "install.ps1"
.\install.ps1 -NoLLM

# Or with LLM
.\install.ps1 -WithLLM
```

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

## System Requirements

| Component | Requirement |
|-----------|-------------|
| OS | macOS 12+, Ubuntu 20.04+, Windows 10+ |
| RAM | 8 GB (16 GB recommended) |
| Disk | 2 GB free space (4 GB with LLM) |
| Python | 3.8+ (for model export) |

### Supported Architectures

| Platform | Architectures |
|----------|---------------|
| macOS | arm64 (Apple Silicon), x86_64 (Intel) |
| Linux | x86_64, aarch64 |
| Windows | x64, arm64 |

## Installation Options

```bash
./install.sh [OPTIONS]

Options:
  --install-dir DIR    Custom installation directory (default: ~/.faria)
  --with-llm           Install LLM components without prompting
  --no-llm             Skip LLM components without prompting
  --gpu                Enable GPU support (CUDA on Linux/Windows)
  --skip-tesseract     Skip Tesseract if already installed system-wide
  --help               Show help message
```

## Installation Directory Structure

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

## Environment Variables (Optional)

If using the default `~/.faria/` location, environment variables are optional - Faria auto-detects the paths.

```bash
# Add to ~/.bashrc or ~/.zshrc
export FARIA_ONNXRUNTIME_PATH="$HOME/.faria/lib/onnxruntime/libonnxruntime.dylib"
export FARIA_DETR_MODEL_PATH="$HOME/.faria/models/detr_layout_detection.onnx"
export FARIA_NEMOTRON_MODEL_PATH="$HOME/.faria/models/nemotron_table_structure.onnx"

# Optional (LLM)
export FARIA_LLAMA_CLI_PATH="$HOME/.faria/bin/llama-cli"
export FARIA_SLM_MODEL_PATH="$HOME/.faria/models/qwen2.5-0.5b-instruct-q8_0.gguf"
```

## Verification

After installation, verify everything is set up correctly:

```bash
./scripts/verify.sh
```

## Uninstallation

```bash
./scripts/uninstall.sh
```

Or manually:

```bash
rm -rf ~/.faria
```

## Using Faria

After installing dependencies, use the Faria Go module:

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
./scripts/install-models.sh
```

### "Python not found" during model export

```bash
# macOS
brew install python@3.11

# Ubuntu/Debian
sudo apt install python3 python3-venv python3-pip
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

## Individual Scripts

| Script | Purpose |
|--------|---------|
| `install.sh` / `install.ps1` | Main orchestration script |
| `scripts/install-onnxruntime.sh` | Install ONNX Runtime |
| `scripts/install-tesseract.sh` | Install Tesseract OCR |
| `scripts/install-models.sh` | Export and install DETR + Nemotron |
| `scripts/install-slm.sh` | Install llama.cpp + Qwen (LLM) |
| `scripts/verify.sh` | Verify installation |
| `scripts/uninstall.sh` | Remove all Faria files |

## License

MIT License - see [LICENSE](LICENSE)

## Support

- **Issues:** https://github.com/exto360-inc/faria-install/issues
- **Main Project:** https://github.com/exto360-inc/faria
