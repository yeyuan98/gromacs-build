# GROMACS Automated Builds

![GitHub Downloads (all assets, all releases)](https://img.shields.io/github/downloads/yeyuan98/gromacs-build/total)

**Production-ready GROMACS binaries. Built automatically. Ready to use.**

## What is This?

Automated build system for [GROMACS](https://www.gromacs.org/) molecular dynamics simulations. We provide pre-compiled GROMACS binaries for Linux — no compilation required.

Each release includes eight build variants covering the two most common SIMD instruction sets (AVX2, AVX-512), both precision modes (single/mixed, double), and optional MPI support. Float builds include CUDA GPU acceleration. MPI builds enable multi-node parallelism.

**Go to Releases, download the variant you need, extract, and run.**

**If this repo saved you time, please give it a :star: :D**

## Available Variants

| File | SIMD | Precision | GPU |
|------|------|-----------|-----|
| `AVX2_256-float.tar.bz2` | AVX2 | Single/Mixed | CUDA |
| `AVX2_256-double.tar.bz2` | AVX2 | Double | CPU only |
| `AVX_512-float.tar.bz2` | AVX-512 | Single/Mixed | CUDA |
| `AVX_512-double.tar.bz2` | AVX-512 | Double | CPU only |
| `AVX2_256-float-mpi.tar.bz2` | AVX2 | Single/Mixed | CUDA + MPI |
| `AVX_512-float-mpi.tar.bz2` | AVX-512 | Single/Mixed | CUDA + MPI |
| `AVX2_256-float-cpu-mpi.tar.bz2` | AVX2 | Single/Mixed | CPU + MPI |
| `AVX_512-float-cpu-mpi.tar.bz2` | AVX-512 | Single/Mixed | CPU + MPI |

## Quick Start

```bash
# 1. Install runtime dependencies
sudo apt update && sudo apt install libgomp1 libblas3 liblapack3

# 2. Extract the build
tar -xjf AVX2_256-float.tar.bz2

# 3. Set up environment
./setup_gromacs.sh

# 4. Verify
gmx --version
```

## System Requirements

- Linux x86_64 (Ubuntu 22.04+, glibc 2.35+)
- CPU with AVX2 or AVX-512 support
- NVIDIA GPU with compute capability 8.6+ (for CUDA/float builds only)
- Minimum 4GB RAM (8GB+ recommended)

## Resources

- **Official GROMACS:** https://www.gromacs.org/
- **Documentation:** https://manual.gromacs.org/
- **Tutorials:** http://www.mdtutorials.com/gmx/
- **Forum:** https://gromacs.bioexcel.eu/

## License

- **GROMACS:** LGPL v2.1 (https://gitlab.com/gromacs/gromacs)
- **Build Scripts:** MIT License
- **This repo:** Provides binaries only — GROMACS remains LGPL

## Disclaimer

**These are unofficial builds, even though source is downloaded from the official FTP.**

- Not affiliated with the GROMACS development team
- Use at your own risk
- Always validate simulation results
- Report build issues here, GROMACS bugs upstream

## How It Works

1. **Trigger** — Manual workflow dispatch on `main`
2. **Download** — Fetch GROMACS source from official FTP
3. **Build** — Compile 8 variants in parallel (2 SIMD x 2 precision + 2 SIMD x float x CUDA+MPI + 2 SIMD x float x CPU+MPI)
4. **Package** — Create per-variant `.tar.bz2` artifacts
5. **Release** — Publish all builds + settings snapshot to GitHub Releases
