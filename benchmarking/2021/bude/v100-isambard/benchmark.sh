#!/bin/bash
# shellcheck disable=SC2034 disable=SC2153

set -eu

setup_env() {
  if ! grep -q bristol/modules/ <<<"$MODULEPATH"; then
    module use /lustre/projects/bristol/modules/modulefiles
  fi

  case "$COMPILER" in
    cce-9.1-classic)
      module load PrgEnv-cray
      module swap cce cce/9.1.1-classic
      module load craype-accel-nvidia70
      MAKE_OPTS='COMPILER=CRAY'
      ;;
    cce-10.0)
      module load PrgEnv-cray
      module swap cce cce/10.0.0
      module load craype-accel-nvidia70
      module load cuda10.2/toolkit/10.2.89
      MAKE_OPTS=''
      ;;
    gcc-8.1)
      module load gcc/8.1.0
      module load cuda10.2/toolkit/10.2.89
      MAKE_OPTS=''
      ;;
    gcc-9.3)
      module load gcc/9.3.0
      module load cuda10.2/toolkit/10.2.89
      MAKE_OPTS=''
      ;;
    llvm-10.0)
      module load cuda10.1/toolkit/10.1.243
      module load llvm/10.0
      module load gcc/9.3.0
      MAKE_OPTS='CC=clang'
      ;;
    pgi-19.10)
      module load cuda10.2/toolkit/10.2.89
      module load pgi/compiler/19.10
      MAKE_OPTS='COMPILER=PGI'
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

export COMPILERS="cce-9.1-classic cce-10.0 gcc-8.1 gcc-9.3 llvm-10.0 pgi-19.10"
export DEFAULT_COMPILER="gcc-9.3"
export MODELS="ocl cuda omp-target acc"
export DEFAULT_MODEL="ocl"
export PLATFORM="v100-isambard"

bash "$PLATFORM_DIR/../common.sh" "$@"
