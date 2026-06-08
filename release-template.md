GROMACS @@GMX_VERSION@@ Linux Builds (Ubuntu 22.04 builder)

## Variants

| File | SIMD | Precision | GPU |
|------|------|-----------|-----|
| AVX2_256-float.tar.bz2 | AVX2_256 | Single/Mixed | CUDA |
| AVX2_256-double.tar.bz2 | AVX2_256 | Double | CPU only |
| AVX_512-float.tar.bz2 | AVX_512 | Single/Mixed | CUDA |
| AVX_512-double.tar.bz2 | AVX_512 | Double | CPU only |
| AVX2_256-float-mpi.tar.bz2 | AVX2_256 | Single/Mixed | CUDA + MPI |
| AVX_512-float-mpi.tar.bz2 | AVX_512 | Single/Mixed | CUDA + MPI |

## Runtime Dependencies
```bash
sudo apt update && sudo apt install @@RUNTIME_DEPS@@
```

## Installation
1. Download the variant matching your CPU and precision needs
2. Extract: `tar -xjf <variant>.tar.bz2`
3. Setup: `./setup_gromacs.sh` or `source bin/GMXRC`
4. Verify: `gmx --version`

## CUDA Builds (float variants)
NVIDIA GPU with compute capability 8.6+ required:
RTX 30/40/50 series, A100, H100, L40, etc.

## MPI Builds (float-mpi variants)
These variants use external MPI for multi-node parallelism.
Additional runtime requirement:
```bash
sudo apt update && sudo apt install openmpi-bin libopenmpi-dev
```

## Build Settings
`build_settings_snapshot.tar.bz2` contains the source configuration and per-variant build configs.
