#!/bin/bash
# shellcheck disable=SC2034 disable=SC2153

set -eu

setup_env() {
  USE_QUEUE=true
  case "$COMPILER" in
    cce-10.0)
      [ -z "$CRAY_CPU_TARGET" ] && module load craype-arm-thunderx2
      module swap cce cce/10.0.1
      MAKE_OPTS='COMPILER=CLANG CC=cc'
      KOKKOS_WGSIZE="1024"
      ;;
    cce-11.0)
      [ -z "$CRAY_CPU_TARGET" ] && module load craype-arm-thunderx2
      module swap cce cce/11.0.0.7500
      MAKE_OPTS='COMPILER=CLANG CC=cc'
      KOKKOS_WGSIZE="1024"
      ;;
    gcc-9.3)
      module swap PrgEnv-{cray,gnu}
      module swap gcc gcc/9.3.0
      MAKE_OPTS='COMPILER=GNU'
      KOKKOS_WGSIZE="256"
      ;;
    arm-20.0)
      module swap PrgEnv-{cray,allinea}
      module swap allinea allinea/20.0.0.0
      MAKE_OPTS='COMPILER=ARM'
      KOKKOS_WGSIZE="128"
      ;;
    hipsycl-201124-gcc9.3)
      module swap PrgEnv-{cray,gnu}
      module load hipsycl/cc320b6-201124/gcc-9.3
      MAKE_OPTS='-DSYCL_RUNTIME=HIPSYCL-NEXT -DHIPSYCL_INSTALL_DIR=/lustre/projects/bristol/modules-arm-phase2/hipsycl/cc320b6-201124-gcc9.3 -DHIPSYCL_PLATFORM=cpu -DNUM_TD_PER_THREAD=32 -DCMAKE_C_COMPILER=gcc -DCMAKE_CXX_COMPILER=g++'
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

export COMPILERS="cce-10.0 cce-11.0 gcc-9.3 arm-20.0 hipsycl-201124-gcc9.3"
export DEFAULT_COMPILER="cce-10.0"
export MODELS="omp kokkos sycl"
export DEFAULT_MODEL="omp"
export PLATFORM="tx2-isambard"

export KOKKOS_BACKEND="OPENMP"
export KOKKOS_ARCH="ARMV8_THUNDERX2"
export KOKKOS_EXTRA_FLAGS="-Ofast -mcpu=thunderx2t99"

bash "$PLATFORM_DIR/../common.sh" "$@"
