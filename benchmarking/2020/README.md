# UoB HPC Benchmarks

This repository contains scripts for running various benchmarks in a reproducible manner.
This is primarily for benchmarking ThunderX2 in Isambard, and other systems that we typically compare against.

### Progress

Result obtained via `amm progress.sc`:

 - [x] babelstream
   - [x] BabelStream: 
     - [x] ampere kokkos       (gcc-10.1)     14L @ 0.54 KB
     - [x] ampere omp          (gcc-10.1)     14L @ 0.54 KB
     - [x] gtx2080ti cuda      (nvcc)         16L @ 0.58 KB
     - [x] gtx2080ti ocl       (gcc-4.8)      17L @ 0.64 KB
     - [x] gtx2080ti omp       (clang)        14L @ 0.54 KB
     - [x] p100 acc            (pgi-19.10)    14L @ 0.54 KB
     - [x] p100 cuda           (cce-10.0)     18L @ 0.68 KB
     - [x] p100 cuda           (gcc-6.1)      16L @ 0.59 KB
     - [x] p100 ocl            (gcc-6.1)      17L @ 0.64 KB
     - [x] p100 omp            (cce-10.0)     14L @ 0.54 KB
     - [x] p100 omp            (llvm-10.0)    14L @ 0.54 KB
     - [x] p100 sycl           (hipsycl-trunk)17L @ 0.67 KB
     - [x] power9 acc          (pgi-19.10)    14L @ 0.54 KB
     - [x] power9 kokkos       (gcc-8.1)      16L @ 0.63 KB
     - [x] power9 omp          (gcc-8.1)      16L @ 0.63 KB
     - [x] power9 omp          (pgi-19.10)    14L @ 0.54 KB
     - [x] power9 omp          (xl-16.1)      14L @ 0.54 KB
     - [x] radeonvii ocl       (gcc-9.1)      17L @ 0.64 KB
     - [x] skl acc             (pgi-20.1)     15L @ 0.63 KB
     - [x] skl kokkos          (gcc-9.3)      15L @ 0.63 KB
     - [x] skl kokkos          (intel-2019)   15L @ 0.63 KB
     - [x] skl omp             (cce-10.0)     15L @ 0.63 KB
     - [x] skl omp             (gcc-9.3)      15L @ 0.63 KB
     - [x] skl omp             (intel-2019)   15L @ 0.63 KB
     - [x] skl omp             (pgi-20.1)     15L @ 0.63 KB
     - [x] tx2 kokkos          (allinea-20.0) 51L @ 2.08 KB
     - [x] tx2 kokkos          (gcc-9.2)      51L @ 2.07 KB
     - [x] tx2 omp             (allinea-20.0) 51L @ 2.08 KB
     - [x] tx2 omp             (cce-10.0)     51L @ 2.07 KB
     - [x] tx2 omp             (gcc-9.2)      51L @ 2.07 KB
     - [x] tx2 sycl            (hipsycl-200527-cce)52L @ 2.11 KB
     - [x] tx2 sycl            (hipsycl-200527-gcc)54L @ 2.23 KB
     - [x] tx2 sycl            (hipsycl-200527simd-gcc)54L @ 2.24 KB
     - [x] v100 acc            (pgi-19.10)    14L @ 0.54 KB
     - [x] v100 cuda           (gcc-7.3)      16L @ 0.59 KB
     - [x] v100 omp            (llvm-trunk)   14L @ 0.54 KB
   - [x] BabelStream(2^29): 
     - [x] ampere kokkos       (gcc-10.1)     16L @ 0.64 KB
     - [x] ampere omp          (gcc-10.1)     16L @ 0.64 KB
     - [x] gtx2080ti cuda      (nvcc)         12L @ 0.36 KB
     - [x] gtx2080ti ocl       (gcc-4.8)      13L @ 0.40 KB
     - [x] gtx2080ti omp       (clang)        9L @ 0.27 KB
     - [x] p100 acc            (pgi-19.10)    14L @ 0.54 KB
     - [x] p100 cuda           (cce-10.0)     18L @ 0.69 KB
     - [x] p100 cuda           (gcc-6.1)      16L @ 0.59 KB
     - [x] p100 ocl            (gcc-6.1)      14L @ 0.57 KB
     - [x] p100 omp            (cce-10.0)     14L @ 0.54 KB
     - [x] p100 omp            (llvm-10.0)    14L @ 0.54 KB
     - [x] p100 sycl           (hipsycl-trunk)17L @ 0.67 KB
     - [x] power9 acc          (pgi-19.10)    16L @ 0.64 KB
     - [x] power9 kokkos       (gcc-8.1)      16L @ 0.64 KB
     - [x] power9 omp          (gcc-8.1)      16L @ 0.64 KB
     - [x] power9 omp          (pgi-19.10)    16L @ 0.64 KB
     - [x] power9 omp          (xl-16.1)      16L @ 0.64 KB
     - [x] radeonvii ocl       (gcc-9.1)      17L @ 0.65 KB
     - [x] skl acc             (pgi-20.1)     15L @ 0.64 KB
     - [x] skl kokkos          (gcc-9.3)      17L @ 0.73 KB
     - [x] skl kokkos          (intel-2019)   17L @ 0.74 KB
     - [x] skl omp             (cce-10.0)     17L @ 0.73 KB
     - [x] skl omp             (gcc-9.3)      17L @ 0.73 KB
     - [x] skl omp             (intel-2019)   15L @ 0.64 KB
     - [x] skl omp             (pgi-20.1)     15L @ 0.64 KB
     - [x] tx2 kokkos          (allinea-20.0) 53L @ 2.19 KB
     - [x] tx2 kokkos          (gcc-9.2)      53L @ 2.19 KB
     - [x] tx2 omp             (allinea-20.0) 53L @ 2.19 KB
     - [x] tx2 omp             (cce-10.0)     53L @ 2.18 KB
     - [x] tx2 omp             (gcc-9.2)      53L @ 2.18 KB
     - [x] tx2 sycl            (hipsycl-200527-cce)52L @ 2.13 KB
     - [x] tx2 sycl            (hipsycl-200527-gcc)56L @ 2.35 KB
     - [x] tx2 sycl            (hipsycl-200527simd-gcc)56L @ 2.35 KB
     - [x] v100 acc            (pgi-19.10)    14L @ 0.54 KB
     - [x] v100 cuda           (gcc-7.3)      16L @ 0.59 KB
     - [x] v100 omp            (llvm-trunk)   14L @ 0.54 KB
 - [x] neutral

 - [x] minifmm

 - [x] tealeaf
   - [x] TeaLeaf: 
     - [x] tx2 kokkos          (allinea-20.0) 49L @ 2.12 KB
     - [x] tx2 kokkos          (gcc-9.2)      109L @ 3.19 KB
     - [x] tx2 omp             (allinea-20.0) 58L @ 2.15 KB
     - [x] tx2 omp             (cce-10.0)     127L @ 5.00 KB
     - [x] tx2 omp             (gcc-9.2)      127L @ 5.20 KB
 - [x] cloverleaf
   - [x] CloverLeaf: 
     - [x] tx2 kokkos          (allinea-20.0) 1401L @ 60.68 KB
     - [x] tx2 kokkos          (gcc-9.2)      1624L @ 70.94 KB
     - [x] tx2 omp             (allinea-20.0) 1882L @ 113.99 KB
     - [x] tx2 omp             (cce-10.0)     11874L @ 687.72 KB
     - [x] tx2 omp             (gcc-9.2)      2262L @ 137.27 KB
