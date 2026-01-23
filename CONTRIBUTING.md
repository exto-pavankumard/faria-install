# Contributing to Faria Install

## Script Synchronization

**macOS/Linux scripts (`.sh`) are the source of truth.**

When modifying shell scripts, always update the corresponding Windows PowerShell scripts (`.ps1`) to maintain feature parity:

| macOS/Linux | Windows |
|-------------|---------|
| `install.sh` | `install.ps1` |
| `scripts/verify.sh` | `scripts/verify.ps1` |
| `scripts/uninstall.sh` | `scripts/uninstall.ps1` |
| `scripts/install-idp.sh` | `scripts/install-idp.ps1` |
| `scripts/install-chat.sh` | `scripts/install-chat.ps1` |
| `scripts/install-onnxruntime.sh` | `scripts/install-onnxruntime.ps1` |
| `scripts/install-models.sh` | `scripts/install-models.ps1` |
| `scripts/install-tesseract.sh` | `scripts/install-tesseract.ps1` |

### Option Naming Conventions

When adding options, follow platform conventions:

| Bash | PowerShell |
|------|------------|
| `--install-dir` | `-InstallDir` |
| `--features` | `-Features` |
| `--gpu` | `-GPU` |
| `--with-llm` | `-WithLLM` |
| `--force` / `-f` | `-Force` |
| `--help` / `-h` | `-Help` |

## Workflow

1. Make changes to the `.sh` script first
2. Mirror the same functionality in the `.ps1` script
3. Run `./build/build.sh` to regenerate the single-file installers
4. Update `INSTALLATION.md` if options changed
5. Test on both platforms if possible
6. Commit both source changes and generated `dist/` files

## Build System

The repository uses a build system to generate single-file installers for `curl | bash` usage:

```
scripts/              # Source scripts (modular)
├── _common.sh        # Shared shell utilities
├── _common.ps1       # Shared PowerShell utilities
├── install-*.sh      # Component installers
└── ...

build/
└── build.sh          # Build script

dist/                 # Generated output (committed to repo)
├── install.sh        # Single-file shell installer
└── install.ps1       # Single-file PowerShell installer
```

### Building

```bash
# Build both installers
./build/build.sh

# Build shell only
./build/build.sh --sh-only

# Build PowerShell only
./build/build.sh --ps1-only
```

### How It Works

The build script:
1. Inlines shared utilities from `scripts/_common.sh`
2. Converts each component script to a function
3. Replaces subscript calls with function calls
4. Generates a self-contained installer

**Important:** Always commit the generated `dist/` files along with source changes.
