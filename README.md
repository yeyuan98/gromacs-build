# Build and Release Workflow

Automated GitHub Actions workflow for building and releasing software artifacts with dynamic runner selection.

## Overview

This workflow automates the complete build and release process:

1. **Dynamic Runner Selection** - Reads `runner-images.txt` to determine which runner to use
2. **Flexible Build Configuration** - Reads `target-cmake.json` for tarball URL and target name
3. **Automated Tarball Extraction** - Supports `.zip`, `.tar.gz`, `.tgz`, `.tar.bz2`, `.tbz2`
4. **CMake Project Detection** - Automatically finds `CMakeLists.txt` directory
5. **Customizable Build Scripts** - Execute `prebuild.sh`, `build.sh`, `postbuild.sh`
6. **Automated Release Creation** - Publishes GitHub release with all artifacts

## Workflow Triggers

The workflow runs automatically when:
- Push to `main` branch with changes to:
  - `runner-images.txt`
  - `target-cmake.json`
  - `prebuild.sh`
  - `build.sh`
  - `postbuild.sh`
- Manual trigger via `workflow_dispatch`

## Required Files

### 1. `runner-images.txt`

Specifies which GitHub Actions runner to use. Must contain a single line with the runner label.

**Example:**
```
ubuntu-24.04
```

**Supported runners:**
- `ubuntu-24.04` - Ubuntu 24.04 LTS
- `ubuntu-22.04` - Ubuntu 22.04 LTS
- `macos-26` - macOS (latest)
- `macos-26-intel` - macOS Intel
- `windows-2025` - Windows Server 2025

**Note:** The workflow uses a matrix strategy with early exit. Only the matching runner will execute the build.

### 2. `target-cmake.json`

JSON configuration file with target name and tarball URL.

**Schema:**
```json
{
  "target_name": "string",
  "tarball_url": "string"
}
```

**Example:**
```json
{
  "target_name": "gromacs",
  "tarball_url": "https://ftp.gromacs.org/gromacs/gromacs-2024.1.tar.gz"
}
```

**Fields:**
- `target_name` (required): Used for release naming (e.g., `gromacs_T20260302-143025`)
- `tarball_url` (required): Direct download URL for the source tarball

### 3. `prebuild.sh`

Shell script executed before the build. Use this to:
- Install build dependencies
- Set environment variables
- Configure the build system

**Example:**
```bash
#!/bin/bash
set -e

# Install dependencies
sudo apt-get update
sudo apt-get install -y cmake g++ libfftw3-dev

# Set environment variables
export CMAKE_PREFIX_PATH=/usr/local
export CC=gcc
export CXX=g++
```

**Requirements:**
- Must be executable (`chmod +x prebuild.sh`)
- Should use `set -e` to fail on errors
- Must work with bash shell (Git Bash on Windows)

### 4. `build.sh`

Shell script that performs the actual build. The working directory will be where `CMakeLists.txt` is located.

**Example:**
```bash
#!/bin/bash
set -e

# Create build directory
mkdir -p build
cd build

# Configure with CMake
cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr/local \
    -DBUILD_TESTING=OFF

# Build
make -j$(nproc)
```

**Requirements:**
- Must be executable (`chmod +x build.sh`)
- Should use `set -e` to fail on errors
- Working directory: location of `CMakeLists.txt`

### 5. `postbuild.sh`

Shell script executed after the build. **MUST create `built_artefact.tar.bz2`** in the working directory.

**Example:**
```bash
#!/bin/bash
set -e

# Package build artifacts
tar -cjf built_artefact.tar.bz2 \
    build/bin \
    build/lib \
    build/include

# Verify artifact exists
if [ ! -f "built_artefact.tar.bz2" ]; then
    echo "Error: Artifact not created"
    exit 1
fi
```

**Requirements:**
- Must be executable (`chmod +x postbuild.sh`)
- **MUST create `built_artefact.tar.bz2`** in the working directory
- Should use `set -e` to fail on errors
- The workflow will fail if `built_artefact.tar.bz2` is not created

## Workflow Process

### Job 1: `prepare`

Reads configuration files and sets outputs:
- `expected-runner`: From `runner-images.txt`
- `target-name`: From `target-cmake.json`
- `tarball-url`: From `target-cmake.json`

### Job 2: `build` (Matrix)

Executes on multiple runners in parallel, but only the matching runner performs the build:

1. **Runner Check** - Compares matrix runner with expected runner
2. **Early Exit** - Non-matching runners exit successfully
3. **Checkout** - Clones the repository
4. **Download Tarball** - Downloads from `tarball_url` using curl/wget
5. **Extract Archive** - Automatically detects and extracts:
   - `.zip` → `unzip`
   - `.tar.gz`, `.tgz` → `tar -xzf`
   - `.tar.bz2`, `.tbz2` → `tar -xjf`
6. **Find CMakeLists.txt** - Recursively searches for first `CMakeLists.txt`
7. **Copy Scripts** - Copies all `.sh` files to working directory
8. **Execute Scripts** - Runs in order:
   - `prebuild.sh`
   - `build.sh`
   - `postbuild.sh`
9. **Verify Artifact** - Checks that `built_artefact.tar.bz2` exists
10. **Upload Artifacts** - Uploads 6 files:
    - `built_artefact.tar.bz2`
    - `runner-images.txt`
    - `target-cmake.json`
    - `prebuild.sh`
    - `build.sh`
    - `postbuild.sh`

### Job 3: `release`

Creates a GitHub release:

1. **Download Artifacts** - Retrieves all build artifacts
2. **Generate Tag** - Format: `{target_name}_T{timestamp}`
   - Example: `gromacs_T20260302-143025`
3. **Create Release** - Uses `softprops/action-gh-release@v2`
   - Creates tag and release
   - Uploads all 6 artifacts
   - Generates release notes

## Release Format

**Tag Format:** `{target_name}_T{YYYYMMDD-HHMMSS}`

**Example:** `gromacs_T20260302-143025`

**Release Assets:**
1. `built_artefact.tar.bz2` - Build output
2. `runner-images.txt` - Runner configuration
3. `target-cmake.json` - Target configuration
4. `prebuild.sh` - Pre-build script
5. `build.sh` - Build script
6. `postbuild.sh` - Post-build script

## Archive Format Support

The workflow automatically detects and extracts these archive formats:

| Extension | Tool | Notes |
|-----------|------|-------|
| `.zip` | `unzip` | Cross-platform |
| `.tar.gz` | `tar -xzf` | Gzip compressed |
| `.tgz` | `tar -xzf` | Gzip compressed (short) |
| `.tar.bz2` | `tar -xjf` | Bzip2 compressed |
| `.tbz2` | `tar -xjf` | Bzip2 compressed (short) |

**Detection Method:** Based on file extension from URL

## CMakeLists.txt Search Strategy

The workflow searches for `CMakeLists.txt` recursively:

1. **Search Root:** Extracted tarball directory
2. **Search Type:** Recursive, depth-first
3. **Stop Condition:** First match found
4. **Working Directory:** Directory containing `CMakeLists.txt`

**Example:**
```
extracted/
├── project-v1.0/           # Tarball created wrapper directory
│   ├── CMakeLists.txt      # ← This is found first
│   ├── src/
│   │   └── CMakeLists.txt  # ← Ignored (search stopped)
│   └── lib/
│       └── CMakeLists.txt  # ← Ignored (search stopped)
```

**Working directory becomes:** `extracted/project-v1.0/`

## Cross-Platform Compatibility

### Linux (Ubuntu)
- Standard bash environment
- All Unix tools available
- No special handling needed

### macOS
- Standard bash environment (zsh fallback)
- All Unix tools available
- May need `brew install` for dependencies

### Windows
- Uses Git Bash (pre-installed on runners)
- Unix tools available via Git Bash
- Scripts must use `shell: bash`

## Error Handling

The workflow fails immediately if:

1. **CMakeLists.txt not found** - Error message with search path
2. **Invalid archive format** - Lists supported formats
3. **Download failure** - curl/wget error
4. **Script execution failure** - `set -e` causes immediate exit
5. **Missing `built_artefact.tar.bz2`** - Verified after `postbuild.sh`

## Example: Building GROMACS

### `runner-images.txt`
```
ubuntu-24.04
```

### `target-cmake.json`
```json
{
  "target_name": "gromacs",
  "tarball_url": "https://ftp.gromacs.org/gromacs/gromacs-2024.1.tar.gz"
}
```

### `prebuild.sh`
```bash
#!/bin/bash
set -e

sudo apt-get update
sudo apt-get install -y \
    cmake \
    g++ \
    libfftw3-dev \
    libopenmpi-dev \
    python3

export CMAKE_PREFIX_PATH=/usr/local
```

### `build.sh`
```bash
#!/bin/bash
set -e

mkdir -p build
cd build

cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DGMX_BUILD_OWN_FFTW=OFF \
    -DGMX_MPI=ON \
    -DGMX_OPENMP=ON \
    -DBUILD_TESTING=OFF

make -j$(nproc)
```

### `postbuild.sh`
```bash
#!/bin/bash
set -e

cd build

tar -cjf built_artefact.tar.bz2 \
    bin/gmx \
    lib/libgromacs* \
    include/gromacs/

if [ ! -f "built_artefact.tar.bz2" ]; then
    echo "Error: Artifact not created"
    exit 1
fi
```

## Security Considerations

1. **Tarball URL:** Only download from trusted HTTPS sources
2. **Script Permissions:** Ensure `.sh` files have proper execute permissions
3. **Token Permissions:** Workflow requires `contents: write` for releases
4. **Artifact Retention:** Default 90 days (configurable in workflow)

## Permissions Required

```yaml
permissions:
  contents: write  # Create releases and tags
  actions: read    # Download artifacts
```

## Troubleshooting

### Issue: Runner mismatch

**Symptom:** All matrix jobs exit early, no build runs

**Solution:** Check that `runner-images.txt` contains a valid runner label:
- `ubuntu-24.04`
- `ubuntu-22.04`
- `macos-26`
- `macos-26-intel`
- `windows-2025`

### Issue: CMakeLists.txt not found

**Symptom:** Workflow fails with "CMakeLists.txt not found"

**Solution:** Verify that the tarball contains a `CMakeLists.txt` file at some level

### Issue: Archive extraction fails

**Symptom:** "Unsupported archive format" error

**Solution:** Ensure tarball URL ends with supported extension:
- `.zip`
- `.tar.gz` or `.tgz`
- `.tar.bz2` or `.tbz2`

### Issue: Script not executable

**Symptom:** "Permission denied" when running `.sh` files

**Solution:** Make scripts executable:
```bash
git update-index --chmod=+x prebuild.sh
git update-index --chmod=+x build.sh
git update-index --chmod=+x postbuild.sh
git commit -m "Make scripts executable"
git push
```

### Issue: Artifact not created

**Symptom:** Workflow fails at "Verify build artifact" step

**Solution:** Ensure `postbuild.sh` creates `built_artefact.tar.bz2` in the working directory

## Manual Trigger

To manually trigger the workflow:

1. Go to **Actions** tab in GitHub
2. Select **"Build and Release"** workflow
3. Click **"Run workflow"**
4. Select branch (usually `main`)
5. Click **"Run workflow"**

## Viewing Results

### Workflow Run
1. Go to **Actions** tab
2. Click on the workflow run
3. View logs for each job

### Release
1. Go to **Releases** section
2. Find release with tag: `{target_name}_T{timestamp}`
3. Download artifacts

## Customization

### Adding New Runners

Edit `.github/workflows/build-and-release.yml`:

```yaml
strategy:
  matrix:
    runner: [ubuntu-24.04, ubuntu-22.04, macos-26, macos-26-intel, windows-2025, your-custom-runner]
```

### Changing Artifact Retention

Modify the `upload-artifact` step:

```yaml
- uses: actions/upload-artifact@v4
  with:
    retention-days: 30  # Change from 90
```

### Adding Release Notes

Modify the release step:

```yaml
- uses: softprops/action-gh-release@v2
  with:
    body: |
      ## Custom Release Notes
      
      Add your custom notes here.
```

## License

This workflow is provided as-is. Modify as needed for your project.

## Contributing

To contribute improvements:
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## Support

For issues or questions:
1. Check the [Troubleshooting](#troubleshooting) section
2. Review GitHub Actions logs
3. Open an issue in the repository
