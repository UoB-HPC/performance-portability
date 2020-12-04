#!/bin/bash
# shellcheck disable=SC2034 disable=SC2153

set -eu

setup_env() {
  if ! grep -q bristol/modules-a64fx/ <<<"$MODULEPATH"; then
    module use /lustre/projects/bristol/modules-a64fx/modulefiles
  fi

  module load cmake

  case "$COMPILER" in
    cce-10.0)
      module restore PrgEnv-cray
      module unload cce-sve
      module load cce/10.0.1
      MAKE_OPTS='COMPILER=CLANG CC=cc WGSIZE=128'
      KOKKOS_EXTRA_FLAGS="-Ofast -mcpu=a64fx"
      ;;
    cce-sve-10.0)
      module restore PrgEnv-cray
      module swap cce-sve cce-sve/10.0.1
      MAKE_OPTS='COMPILER=CRAY WGSIZE=128'
      KOKKOS_EXTRA_FLAGS="-Ofast -mcpu=a64fx"
      ;;
    gcc-8.1)
      module load gcc/8.1.0
      MAKE_OPTS='COMPILER=GNU WGSIZE=128'
      KOKKOS_EXTRA_FLAGS="-Ofast -march=armv8.2-a+sve"
      ;;
    gcc-11.0)
      module load gcc/11-20201025
      MAKE_OPTS='COMPILER=GNU WGSIZE=128'
      KOKKOS_EXTRA_FLAGS="-Ofast -mcpu=a64fx"
      ;;
    hipsycl-201124-gcc11.0)
      module load hipsycl/cc320b6-201124/gcc-11.0
      MAKE_OPTS='-DSYCL_RUNTIME=HIPSYCL-NEXT -DHIPSYCL_INSTALL_DIR=/lustre/projects/bristol/modules-a64fx/hipsycl/cc320b6-201124/gcc-11.0 -DHIPSYCL_PLATFORM=cpu -DNUM_TD_PER_THREAD=128 -DCMAKE_C_COMPILER=gcc -DCMAKE_CXX_COMPILER=g++'
      ;;
    *)
      echo
      echo "Invalid compiler '$COMPILER'."
      usage
      exit 1
      ;;
  esac
}
export -f setup_env

script="$(realpath "$0")"
SCRIPT_DIR="$(realpath "$(dirname "$script")")"
PLATFORM_DIR="$(realpath "$(dirname "$script")")"
export SCRIPT_DIR PLATFORM_DIR

export COMPILERS="cce-10.0 cce-sve-10.0 gcc-8.1 gcc-11.0 hipsycl-201124-gcc11.0"
export DEFAULT_COMPILER="cce-sve-10.0"
export MODELS="omp sycl"
export DEFAULT_MODEL="omp"
export PLATFORM="a64fx-isambard"

export KOKKOS_BACKEND="OPENMP"
export KOKKOS_ARCH="ARMV81"
export KOKKOS_WGSIZE="128"

bash "$PLATFORM_DIR/../common.sh" "$@"
