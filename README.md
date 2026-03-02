# GROMACS Automated Builds

![GitHub Downloads (all assets, all releases)](https://img.shields.io/github/downloads/yeyuan98/gromacs-build/total)

**Production-ready GROMACS binaries. Built automatically. Ready to use.**

## What is This?

Automated build system for GROMACS molecular dynamics simulations. We provide pre-compiled GROMACS binaries for different platforms and configurations - no compilation required.

**Just go to Release, download the one you want, extract, and run.**

**If this repo saved you time, please give it a ⭐️ :D**

## Requesting New Builds

Open an issue with:

**Build Request Template:**
```
GROMACS Version: [e.g., 2026.0, 2024.4]
Platform: [e.g., Ubuntu 24.04]
Configuration:
  - GPU: [CUDA 12.x, OpenCL, OFF]
  - MPI: [ON, OFF]
  - Precision: [Single, Double]
  - SIMD: [AVX2, AVX-512, SSE4.1]
  - Library: [Static, Shared]
```

Note: with GROMACS quarterly releases, this repo will be updated with selected builds on Ubuntu 24.04.

## Resources

- **Official GROMACS:** https://www.gromacs.org/
- **Documentation:** https://manual.gromacs.org/
- **Tutorials:** http://www.mdtutorials.com/gmx/
- **Forum:** https://gromacs.bioexcel.eu/

## License

- **GROMACS:** LGPL v2.1 (https://gitlab.com/gromacs/gromacs)
- **Build Scripts:** MIT License
- **This repo:** Provides binaries only - GROMACS remains LGPL

## Disclaimer

**Even if source is downloaded from Official FTP, these are unofficial builds.**

- Not affiliated with GROMACS development team
- Use at your own risk
- Always validate simulation results
- Report build issues here, GROMACS bugs upstream

## How It Works

This repo uses GitHub Actions to automatically build GROMACS:

1. **Trigger** - Push to `main` or manual dispatch
2. **Download** - Fetch GROMACS source from official FTP
3. **Build** - Compile with optimized settings
4. **Package** - Create distributable artifact
5. **Release** - Publish to GitHub Releases


**Built with ❤️ for molecular dynamics**
