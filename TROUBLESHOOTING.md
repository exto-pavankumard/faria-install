# Troubleshooting Guide

Common installation errors and their solutions.

## Table of Contents

- [Ubuntu/Debian](#ubuntudebian)
  - [Broken PPA causing apt update to fail](#broken-ppa-causing-apt-update-to-fail)
  - [ModuleNotFoundError: No module named '_ctypes' / '_bz2' / '_lzma' / '_sqlite3'](#modulenotfounderror-no-module-named-_ctypes--_bz2--_lzma--_sqlite3)
  - [pyenv: command not found](#pyenv-command-not-found)
  - [Git LFS not installed](#git-lfs-not-installed)
- [macOS](#macos)
  - [CoreML not working](#coreml-not-working)
  - [Homebrew Python issues](#homebrew-python-issues)
- [All Platforms](#all-platforms)
  - [ONNX Runtime library not found](#onnx-runtime-library-not-found)
  - [Model file not found](#model-file-not-found)
  - [Model export fails with out of memory](#model-export-fails-with-out-of-memory)
  - [Slow performance](#slow-performance)
- [CGO and Build Errors](#cgo-and-build-errors)
  - [Package not found in pkg-config search path](#package-not-found-in-pkg-config-search-path)
  - [Cannot find -lleptonica or -ltesseract](#cannot-find--lleptonica-or-cannot-find--ltesseract)
  - [Finding Library Locations](#finding-library-locations)
  - [Manual CGO Flags](#manual-cgo-flags)
- [Tesseract / Leptonica Issues](#tesseract--leptonica-issues)
  - [Failed to initialize tesseract](#failed-to-initialize-tesseract)
  - [Error opening data file](#error-opening-data-file)
- [OpenCV Issues](#opencv-issues)
  - [gocv: cannot find OpenCV](#gocv-cannot-find-opencv)
  - [OpenCV Version Mismatch](#opencv-version-mismatch)
  - [ArUco Module Compilation Errors](#aruco-module-compilation-errors-gocv)
- [MuPDF Issues](#mupdf-issues)
  - [cannot find -lmupdf](#cannot-find--lmupdf)
  - [undefined reference to fz_xxx](#undefined-reference-to-fz_xxx)
- [ONNX Runtime Build Issues](#onnx-runtime-build-issues)
  - [cannot find -lonnxruntime](#cannot-find--lonnxruntime)
  - [libonnxruntime.so: cannot open shared object file](#libonnxruntimeso-cannot-open-shared-object-file)
- [Platform-Specific Issues](#platform-specific-issues)
  - [macOS: library not loaded / SIP Issues](#macos-library-not-loaded--sip-issues)
  - [macOS: Apple Silicon vs Intel](#macos-apple-silicon-vs-intel)
  - [Linux: Permission Denied on /usr/local](#linux-permission-denied-on-usrlocal)
  - [Windows: Path Issues](#windows-path-issues)
  - [Windows: MSYS2 vs Native](#windows-msys2-vs-native)
- [Quick Diagnostic Commands](#quick-diagnostic-commands)

---

## Ubuntu/Debian

### Broken PPA causing apt update to fail

**Error:**
```
E: The repository 'https://ppa.launchpadcontent.net/xxx/ubuntu noble Release' does not have a Release file.
N: Updating from such a repository can't be done securely, and is therefore disabled by default.
✗ Tesseract OCR installation failed
```

**Cause:** A third-party PPA on your system doesn't support your Ubuntu version, causing `apt update` to fail.

**Solution:**

Remove the broken PPA:

```bash
# Replace 'ppa-name' with the actual PPA from the error message
sudo add-apt-repository --remove ppa:username/ppa-name
```

Or manually delete it:

```bash
# List PPA files
ls /etc/apt/sources.list.d/

# Remove the problematic one
sudo rm /etc/apt/sources.list.d/problematic-ppa.list
```

Then retry the installation:

```bash
sudo apt update
./install.sh --no-llm
```

---

### ModuleNotFoundError: No module named '_ctypes' / '_bz2' / '_lzma' / '_sqlite3'

**Error:**
```
ModuleNotFoundError: No module named '_ctypes'
```
or
```
ModuleNotFoundError: No module named '_bz2'
```
or similar errors for `_lzma`, `_sqlite3`, `_ssl`, etc.

**Cause:** Python was compiled without required system libraries. This commonly happens with pyenv-installed Python when development headers weren't installed beforehand.

**Solution:**

Option 1 - Install all dependencies and rebuild Python with pyenv:

```bash
# Install ALL required development libraries
sudo apt install -y build-essential libssl-dev zlib1g-dev libbz2-dev \
  libreadline-dev libsqlite3-dev libncursesw5-dev xz-utils tk-dev \
  libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev

# Rebuild Python (this will compile with all modules)
pyenv install 3.12.12 --force

# Retry installation
./install.sh --no-llm
```

Option 2 - Use system Python instead:

```bash
# Install system Python
sudo apt install -y python3 python3-venv python3-pip

# Run installer with system Python
PATH="/usr/bin:$PATH" ./install.sh --no-llm
```

---

### pyenv: command not found

**Error:**
```
pyenv: command not found
```

**Cause:** pyenv is installed but not in your PATH.

**Solution:**

Add pyenv to your PATH:

```bash
export PATH="$HOME/.pyenv/bin:$PATH"
eval "$(pyenv init -)"
```

To make this permanent, add those lines to your `~/.bashrc` or `~/.zshrc`:

```bash
echo 'export PATH="$HOME/.pyenv/bin:$PATH"' >> ~/.bashrc
echo 'eval "$(pyenv init -)"' >> ~/.bashrc
source ~/.bashrc
```

---

### Git LFS not installed

**Error:**
```
git: 'lfs' is not a git command.
```
or
```
✗ Git LFS is required for Nemotron model
```

**Cause:** Git LFS (Large File Storage) is not installed, which is required for downloading the Nemotron model.

**Solution:**

```bash
# Install Git LFS
sudo apt install -y git-lfs

# Initialize Git LFS
git lfs install

# Retry installation
./install.sh --no-llm
```

---

## macOS

### CoreML not working

**Symptom:** Model inference is slow on Apple Silicon, not using Neural Engine.

**Cause:** ONNX Runtime was installed via Homebrew, which doesn't include CoreML support.

**Solution:**

Do NOT use Homebrew for ONNX Runtime:

```bash
# Wrong (no CoreML support)
brew install onnxruntime

# Correct - use the installer which downloads the official release
./install.sh --no-llm
```

If you previously installed via Homebrew, uninstall it first:

```bash
brew uninstall onnxruntime
rm -rf ~/.faria/lib/onnxruntime
./install.sh --no-llm
```

---

### Homebrew Python issues

**Error:**
```
Python not found
```
or
```
python3: command not found
```

**Solution:**

```bash
brew install python@3.12
```

If Python is installed but not found:

```bash
export PATH="/opt/homebrew/bin:$PATH"
```

---

## All Platforms

### ONNX Runtime library not found

**Error:**
```
ONNX Runtime library not found
```
or
```
failed to load ONNX Runtime: library not found
```

**Cause:** The ONNX Runtime library is missing or the path is incorrect.

**Solution:**

1. Verify the library exists:

```bash
# macOS
ls -la ~/.faria/lib/onnxruntime/libonnxruntime.dylib

# Linux
ls -la ~/.faria/lib/onnxruntime/libonnxruntime.so

# Windows
dir %USERPROFILE%\.faria\lib\onnxruntime\onnxruntime.dll
```

2. If missing, reinstall ONNX Runtime:

```bash
./scripts/install-onnxruntime.sh
```

3. If using a custom location, set the environment variable:

```bash
# macOS
export FARIA_ONNXRUNTIME_PATH="$HOME/.faria/lib/onnxruntime/libonnxruntime.dylib"

# Linux
export FARIA_ONNXRUNTIME_PATH="$HOME/.faria/lib/onnxruntime/libonnxruntime.so"
```

---

### Model file not found

**Error:**
```
Model file not found: detr_layout_detection.onnx
```
or
```
failed to load model: file not found
```

**Cause:** ML models were not exported or are in a different location.

**Solution:**

1. Verify models exist:

```bash
ls -la ~/.faria/models/
```

Expected files:
- `detr_layout_detection.onnx` (~350 MB)
- `nemotron_table_structure.onnx` (~200 MB)
- `qwen2.5-0.5b-instruct-q8_0.gguf` (~530 MB, optional)

2. If missing, re-run model installation:

```bash
./scripts/install-models.sh
```

3. If using a custom location, set environment variables:

```bash
export FARIA_DETR_MODEL_PATH="/path/to/detr_layout_detection.onnx"
export FARIA_NEMOTRON_MODEL_PATH="/path/to/nemotron_table_structure.onnx"
```

---

### Model export fails with out of memory

**Error:**
```
torch.cuda.OutOfMemoryError: CUDA out of memory
```
or
```
MemoryError
```
or system becomes unresponsive during model export.

**Cause:** Model export requires significant RAM (~8-16 GB).

**Solution:**

1. Close other applications to free memory

2. Export models one at a time:

```bash
# DETR only
./scripts/install-models.sh --skip-nemotron

# Nemotron only (after DETR completes)
./scripts/install-models.sh --skip-detr
```

3. Use a machine with more RAM (16 GB recommended)

4. On Linux, increase swap space temporarily:

```bash
sudo fallocate -l 8G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# Run installation
./install.sh --no-llm

# Remove swap after completion
sudo swapoff /swapfile
sudo rm /swapfile
```

---

### Slow performance

**Symptom:** Document processing is slower than expected.

**Possible causes and solutions:**

1. **GPU/Neural Engine not being used**

   - macOS: Ensure ONNX Runtime is from official release, not Homebrew
   - Linux/Windows: Reinstall with GPU support:

   ```bash
   ./install.sh --gpu --no-llm
   ```

2. **Insufficient worker threads**

   In your Go code:

   ```go
   config := faria.DefaultConfig()
   config.Document.WorkerCount = 8  // Increase based on CPU cores
   ```

3. **LLM running on CPU**

   In your Go code:

   ```go
   config.Document.SLMConfig.GPULayers = 99  // Offload all layers to GPU
   ```

---

## CGO and Build Errors

These errors occur when building Go programs that use Faria's C bindings (OpenCV, Tesseract, MuPDF).

### "Package not found in pkg-config search path"

**Error:**
```
Package leptonica was not found in the pkg-config search path.
Perhaps you should add the directory containing `leptonica.pc'
to the PKG_CONFIG_PATH environment variable
```

**Cause:** The `.pc` files have different names on different platforms.

| Platform | Leptonica pkg-config name | Tesseract pkg-config name |
|----------|---------------------------|---------------------------|
| macOS (Homebrew) | `leptonica` | `tesseract` |
| Ubuntu/Debian | `lept` | `tesseract` |
| Fedora/RHEL | `lept` | `tesseract` |

**Solution:**
```bash
# On Ubuntu/Debian, use 'lept' instead of 'leptonica'
pkg-config --cflags lept tesseract
pkg-config --libs lept tesseract

# Verify the .pc file exists
dpkg -L libleptonica-dev | grep -E "\.pc$"
# Output: /usr/lib/x86_64-linux-gnu/pkgconfig/lept.pc
```

### "Cannot find -lleptonica" or "Cannot find -ltesseract"

**Error:**
```
/usr/bin/ld: cannot find -lleptonica
/usr/bin/ld: cannot find -ltesseract
```

**Cause:** Development libraries not installed or not in library path.

**Solution:**

Ubuntu/Debian:
```bash
sudo apt install libleptonica-dev libtesseract-dev
```

Fedora/RHEL:
```bash
sudo dnf install leptonica-devel tesseract-devel
```

macOS:
```bash
brew install leptonica tesseract
```

### Finding Library Locations

**Find headers:**
```bash
# Leptonica
find /usr -name "allheaders.h" 2>/dev/null

# Tesseract
find /usr -name "baseapi.h" 2>/dev/null
```

**Find libraries:**
```bash
ldconfig -p | grep -E "liblept|libtesseract"
```

**Check what packages installed:**
```bash
# Ubuntu/Debian
dpkg -L libleptonica-dev
dpkg -L libtesseract-dev

# Fedora/RHEL
rpm -ql leptonica-devel
rpm -ql tesseract-devel
```

### Manual CGO Flags

If auto-detection fails, set flags manually:

```bash
# Ubuntu/Debian
export CGO_CPPFLAGS="-I/usr/include"
export CGO_LDFLAGS="-L/usr/lib/x86_64-linux-gnu -llept -ltesseract"

# macOS (Homebrew Apple Silicon)
export CGO_CPPFLAGS="-I/opt/homebrew/include"
export CGO_LDFLAGS="-L/opt/homebrew/lib -lleptonica -ltesseract"

# macOS (Homebrew Intel)
export CGO_CPPFLAGS="-I/usr/local/include"
export CGO_LDFLAGS="-L/usr/local/lib -lleptonica -ltesseract"
```

---

## Tesseract / Leptonica Issues

### "Failed to initialize tesseract"

**Cause:** Tesseract language data files not found.

**Solution:**
```bash
# Check TESSDATA_PREFIX
echo $TESSDATA_PREFIX

# Find tessdata directory
find /usr -name "tessdata" -type d 2>/dev/null

# Set the prefix
export TESSDATA_PREFIX=/usr/share/tesseract-ocr/4.00/tessdata

# Or on macOS
export TESSDATA_PREFIX=/opt/homebrew/share/tessdata
```

### "Error opening data file"

**Error:**
```
Error opening data file /usr/share/tesseract-ocr/4.00/tessdata/eng.traineddata
```

**Solution:**
```bash
# Ubuntu/Debian
sudo apt install tesseract-ocr-eng

# macOS
brew install tesseract-lang

# Or download manually
wget https://github.com/tesseract-ocr/tessdata/raw/main/eng.traineddata
sudo mv eng.traineddata /usr/share/tesseract-ocr/4.00/tessdata/
```

---

## OpenCV Issues

### "gocv: cannot find OpenCV"

**Error:**
```
Package opencv4 was not found in the pkg-config search path
```

**Solution:**

Ubuntu/Debian:
```bash
sudo apt install libopencv-dev
pkg-config --modversion opencv4
```

macOS:
```bash
brew install opencv
export PKG_CONFIG_PATH="/opt/homebrew/lib/pkgconfig:$PKG_CONFIG_PATH"
```

### OpenCV Version Mismatch

**Error:**
```
undefined reference to `cv::xxx'
```

**Solution:** Check your OpenCV version and use appropriate build tags:
```bash
# Check version
pkg-config --modversion opencv4

# For OpenCV 3.x
go build -tags opencv3 ./...

# For OpenCV 4.x (default)
go build ./...
```

### ArUco Module Compilation Errors (gocv)

**Error:**
```
aruco.h:56:62: error: 'ArucoDetectorParameters' was not declared in this scope
aruco.h:82:1: error: 'ArucoDictionary' does not name a type
aruco.h:84:1: error: 'ArucoDetector' does not name a type
```

**Cause:** The OpenCV ArUco module headers are missing. On Ubuntu, the default `libopencv-dev` package may not include the contrib modules (which contain ArUco). Additionally, gocv v0.42.0 requires OpenCV 4.7+ due to ArUco API changes.

**Solution 1: Install OpenCV contrib modules (may work for older gocv versions)**

```bash
sudo apt install libopencv-contrib-dev

# Verify ArUco headers are available
ls /usr/include/opencv4/opencv2/aruco.hpp
```

**Solution 2: Downgrade gocv (quick fix for OpenCV 4.5.x)**

If you have OpenCV 4.5.x and don't want to upgrade:
```bash
go get gocv.io/x/gocv@v0.32.1
go mod tidy
```

**Solution 3: Build OpenCV from source with contrib modules (recommended)**

For full compatibility with gocv v0.42.0, build OpenCV 4.10.0 from source:

```bash
# Install build dependencies
sudo apt install -y build-essential cmake git pkg-config \
    libgtk-3-dev libavcodec-dev libavformat-dev libswscale-dev \
    libv4l-dev libxvidcore-dev libx264-dev libjpeg-dev libpng-dev \
    libtiff-dev gfortran openexr libatlas-base-dev python3-dev \
    python3-numpy libtbb2 libtbb-dev libdc1394-dev

# Remove existing OpenCV to avoid conflicts
sudo apt remove -y libopencv-dev libopencv-contrib-dev

# Clone OpenCV and contrib (use same parent directory for both!)
mkdir -p ~/opencv_build && cd ~/opencv_build
git clone --depth 1 --branch 4.10.0 https://github.com/opencv/opencv.git
git clone --depth 1 --branch 4.10.0 https://github.com/opencv/opencv_contrib.git

# Build
cd opencv && mkdir build && cd build
cmake -D CMAKE_BUILD_TYPE=RELEASE \
    -D CMAKE_INSTALL_PREFIX=/usr/local \
    -D OPENCV_EXTRA_MODULES_PATH=~/opencv_build/opencv_contrib/modules \
    -D OPENCV_ENABLE_NONFREE=ON \
    -D BUILD_EXAMPLES=OFF \
    -D WITH_TBB=ON \
    -D WITH_V4L=ON \
    -D WITH_GTK=ON \
    ..

# Verify "aruco" appears in "To be built" modules list, then:
make -j$(nproc)
sudo make install
sudo ldconfig

# Verify installation
pkg-config --modversion opencv4
# Should output: 4.10.0
```

**Common build error: "No modules has been found"**

```
CMake Error: No modules has been found: ~/opencv_build/opencv_contrib/modules
```

This means the `OPENCV_EXTRA_MODULES_PATH` doesn't match where you cloned `opencv_contrib`. Ensure both repos are in the same parent directory and the path is correct:

```bash
# Verify the path exists
ls ~/opencv_build/opencv_contrib/modules

# If you cloned to a different location, adjust the cmake command:
cmake ... -D OPENCV_EXTRA_MODULES_PATH=/path/to/your/opencv_contrib/modules ...
```

---

## MuPDF Issues

### "cannot find -lmupdf"

**Solution:**

Ubuntu/Debian:
```bash
sudo apt install libmupdf-dev mupdf-tools

# May also need these dependencies
sudo apt install libfreetype6-dev libharfbuzz-dev libjpeg-dev libopenjp2-7-dev
```

macOS:
```bash
brew install mupdf
```

### "undefined reference to fz_xxx"

**Cause:** MuPDF library version mismatch or missing dependencies.

**Solution:**
```bash
# Ubuntu - install all MuPDF dependencies
sudo apt install libmupdf-dev libfreetype6-dev libharfbuzz-dev \
    libjpeg-dev libopenjp2-7-dev libjbig2dec0-dev libmujs-dev
```

---

## ONNX Runtime Build Issues

### "cannot find -lonnxruntime"

**Error:**
```
/usr/bin/ld: cannot find -lonnxruntime
```

**Solution:**
```bash
# Verify installation
ls $ONNXRUNTIME_ROOT/lib/

# Set library path
export LD_LIBRARY_PATH=$ONNXRUNTIME_ROOT/lib:$LD_LIBRARY_PATH  # Linux
export DYLD_LIBRARY_PATH=$ONNXRUNTIME_ROOT/lib:$DYLD_LIBRARY_PATH  # macOS

# Set CGO flags
export CGO_CPPFLAGS="-I$ONNXRUNTIME_ROOT/include"
export CGO_LDFLAGS="-L$ONNXRUNTIME_ROOT/lib -lonnxruntime"
```

### "libonnxruntime.so: cannot open shared object file"

**Runtime error** - library found at build time but not at runtime.

**Solution:**
```bash
# Add to LD_LIBRARY_PATH permanently
echo 'export LD_LIBRARY_PATH=/usr/local/onnxruntime/lib:$LD_LIBRARY_PATH' >> ~/.bashrc
source ~/.bashrc

# Or create a system-wide config
echo "/usr/local/onnxruntime/lib" | sudo tee /etc/ld.so.conf.d/onnxruntime.conf
sudo ldconfig
```

---

## Platform-Specific Issues

### macOS: "library not loaded" / SIP Issues

**Error:**
```
dyld: Library not loaded: @rpath/libonnxruntime.dylib
```

**Solution:**
```bash
# Use DYLD_LIBRARY_PATH
export DYLD_LIBRARY_PATH=/usr/local/onnxruntime/lib:$DYLD_LIBRARY_PATH

# Or install library to system path
sudo cp /usr/local/onnxruntime/lib/*.dylib /usr/local/lib/
```

### macOS: Apple Silicon vs Intel

Different download URLs and paths:

```bash
# Check architecture
uname -m
# arm64 = Apple Silicon
# x86_64 = Intel

# Apple Silicon Homebrew prefix
/opt/homebrew/

# Intel Homebrew prefix
/usr/local/
```

### Linux: Permission Denied on /usr/local

**Solution:**
```bash
# Use sudo for system-wide installation
sudo mv onnxruntime-linux-x64-1.17.0 /usr/local/onnxruntime

# Or install to user directory
mv onnxruntime-linux-x64-1.17.0 ~/onnxruntime
export ONNXRUNTIME_ROOT=~/onnxruntime
```

### Windows: Path Issues

**Common problems:**
- Spaces in paths
- Forward vs backward slashes
- Missing PATH entries

**Solutions:**
```powershell
# Use quotes for paths with spaces
$env:CGO_CPPFLAGS = '"-IC:\Program Files\include"'

# Ensure MSYS2 bin is in PATH
$env:PATH = "C:\msys64\ucrt64\bin;C:\msys64\usr\bin;$env:PATH"
```

### Windows: MSYS2 vs Native

Some tools work differently in MSYS2 vs native Windows:

```bash
# In MSYS2 terminal
./scripts/test.sh

# In PowerShell
.\scripts\test.ps1
```

---

## Quick Diagnostic Commands

### Check All Dependencies

```bash
# Go
go version

# Tesseract
tesseract --version

# pkg-config packages
pkg-config --modversion lept tesseract opencv4 2>/dev/null || \
pkg-config --modversion leptonica tesseract opencv4 2>/dev/null

# MuPDF
mutool -v

# ONNX Runtime
ls $ONNXRUNTIME_ROOT/lib/libonnxruntime* 2>/dev/null && echo "ONNX Runtime: Found"
```

### Check CGO Environment

```bash
echo "CGO_ENABLED: ${CGO_ENABLED:-1}"
echo "CGO_CPPFLAGS: $CGO_CPPFLAGS"
echo "CGO_LDFLAGS: $CGO_LDFLAGS"
echo "LD_LIBRARY_PATH: $LD_LIBRARY_PATH"
echo "PKG_CONFIG_PATH: $PKG_CONFIG_PATH"
```

### Run Verbose Build

```bash
CGO_LDFLAGS_ALLOW=".*" go build -v -x ./... 2>&1 | head -100
```

---

## Still Having Issues?

If your issue isn't listed here:

1. Run the verification script for diagnostics:

   ```bash
   ./scripts/verify.sh
   ```

2. Open an issue with:
   - Your OS and version
   - The full error message
   - Output of `./scripts/verify.sh`

   https://github.com/exto360-inc/faria-install/issues
