#!/bin/bash
# shellcheck disable=SC2034 disable=SC2153

set -eu

setup_env() {
  if ! grep -q bristol/modules/ <<<"$MODULEPATH"; then
    module use /lustre/projects/bristol/modules/modulefiles
  fi

  case "$COMPILER" in
    gcc-9.3)
      module load gcc/9.3.0
      module load cuda10.2/toolkit/10.2.89
      MAKE_OPTS=''
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

export COMPILERS="gcc-9.3"
export DEFAULT_COMPILER="gcc-9.3"
export MODELS="ocl"
export DEFAULT_MODEL="ocl"
export PLATFORM="v100-isambard"

bash "$PLATFORM_DIR/../common.sh" "$@"
