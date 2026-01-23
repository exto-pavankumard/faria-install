# Dependency Versions

Version requirements for Faria dependencies are defined in `versions.json`.

## Quick Version Check

```bash
# Check installed versions
pkg-config --modversion lept tesseract opencv4

# Run full verification
./scripts/verify.sh
```

## Version Requirements

Version requirements are maintained in `versions.json`:

- **minimum**: Lowest version that should work
- **tested**: Versions confirmed working on specific platforms

### Current Minimum Versions

| Dependency | Min Version | Notes |
|------------|-------------|-------|
| Leptonica | 1.82.0 | Required by Tesseract |
| Tesseract | 5.0.0 | LSTM engine required |
| OpenCV | 4.5.0 | Image processing |
| MuPDF | 1.23.0 | PDF processing |
| ONNX Runtime | 1.22.0 | CoreML support on macOS |
| Python | 3.12.0 | For model export only |

### Tested Configurations

Configurations verified to work together:

#### macOS (Apple Silicon)
```
leptonica: 1.87.0
tesseract: 5.5.2
opencv: 4.12.0
mupdf: 1.25.0
onnxruntime: 1.22.0
```

#### Ubuntu 24.04
```
leptonica: 1.84.1
tesseract: 5.3.4
opencv: 4.6.0
mupdf: 1.23.0
onnxruntime: 1.22.0
```

## Updating Tested Versions

When you verify a new platform/version combination works:

1. Edit `versions.json`
2. Add or update entry under `tested.<platform>`
3. Include the test date

Example:
```json
"tested": {
  "your-platform": {
    "leptonica": "x.x.x",
    "tesseract": "x.x.x",
    "opencv": "x.x.x",
    "mupdf": "x.x.x",
    "onnxruntime": "x.x.x",
    "date": "2025-01-23"
  }
}
```

## Known Version Issues

### Tesseract 4.x vs 5.x
- Tesseract 4.x lacks the LSTM engine required for accuracy
- Always use Tesseract 5.0.0 or higher
- Install: `brew install tesseract` (macOS) or `apt install tesseract-ocr` (Linux)

### Leptonica < 1.82.0
- Missing functions required by Tesseract 5.x
- Usually updated automatically with Tesseract
- If issues occur: `brew upgrade leptonica` (macOS)

### OpenCV with CGO
- Ensure development headers are installed
- Linux: `apt install libopencv-dev`
- macOS: Homebrew includes headers by default

## Verifying Your Installation

Run the verification script to check all dependencies:

```bash
./scripts/verify.sh

# Expected output:
# Checking dependency versions...
# ✓ leptonica: 1.87.0 (min: 1.82.0)
# ✓ tesseract: 5.5.2 (min: 5.0.0)
# ✓ opencv: 4.12.0 (min: 4.5.0)
# ✓ mupdf: 1.25.0
```

If any version is below the minimum, you'll see a warning with instructions.
