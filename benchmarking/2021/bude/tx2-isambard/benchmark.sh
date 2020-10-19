#!/bin/bash
# shellcheck disable=SC2034 disable=SC2153

set -eu

setup_env() {
  case "$COMPILER" in
    cce-10.0)
      [ -z "$CRAY_CPU_TARGET" ] && module load craype-arm-thunderx2
      module swap cce cce/10.0.1
      MAKE_OPTS='COMPILER=CLANG CC=cc'
      ;;
    gcc-9.3)
      module swap PrgEnv-{cray,gnu}
      module swap gcc gcc/9.3.0
      MAKE_OPTS='COMPILER=GNU'
      ;;
    arm-20.0)
      module swap PrgEnv-{cray,allinea}
      module swap allinea allinea/20.0.0.0
      MAKE_OPTS='COMPILER=ARM'
      ;;
    hipsycl-200527-gcc)
      echo "$COMPILER is not implemented" && exit 99
      module swap PrgEnv-{cray,gnu}
      module load hipsycl/gcc/200527
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

export COMPILERS="cce-10.0 gcc-9.3 arm-20.0 hipsycl-200527-gcc"
export DEFAULT_COMPILER="cce-10.0"
export MODELS="omp kokkos sycl"
export DEFAULT_MODEL="omp"
export PLATFORM="tx2-isambard"

bash "$PLATFORM_DIR/../common.sh" "$@"
