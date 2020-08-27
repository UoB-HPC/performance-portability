#!/bin/bash

DEFAULT_COMPILER=fujitsu-4.1
DEFAULT_MODEL=mpi
function usage() {
  echo
  echo "Usage: ./benchmark.sh build|run [MODEL] [COMPILER]"
  echo
  echo "Valid model and compiler options:"
  echo "  mpi | omp"
  echo "    arm-20.2"
  echo "    fujitsu-4.1"
  echo "    gcc-8.3"
  echo
  echo "  kokkos"
  echo "    arm-20.2"
  echo "    fujitsu-4.1"
  echo "    gcc-8.3"
  echo
  echo "The default configuration is '$DEFAULT_MODEL $DEFAULT_COMPILER'."
  echo
}

# Process arguments
if [ $# -lt 1 ]; then
  usage
  exit 1
fi

ACTION="$1"
export MODEL="${2:-$DEFAULT_MODEL}"
export COMPILER="${3:-$DEFAULT_COMPILER}"
SCRIPT="$(realpath "$0")"
SCRIPT_DIR="$(realpath "$(dirname "$SCRIPT")")"
source "${SCRIPT_DIR}/../common.sh"
export CONFIG="a64fx_${COMPILER}_${MODEL}"
export SRC_DIR="$PWD/CloverLeaf_ref"
export RUN_DIR="$PWD/CloverLeaf-$CONFIG"
export BENCHMARK_EXE="clover_leaf"

# Set up the environment
case "$COMPILER" in
arm-20.2)
  module purge
  module load arm/20.2
  module load openmpi/4.0.3/arm-20.0
  MAKE_OPTS='COMPILER=ARM'
  MAKE_OPTS+=' FLAGS_ARM="-Ofast -ffast-math -ffp-contract=fast -mcpu=a64fx -funroll-loops -fiterative-reciprocal"'
  MAKE_OPTS+=' CFLAGS_ARM="-Ofast -ffast-math -ffp-contract=fast -mcpu=a64fx -funroll-loops -fiterative-reciprocal"'
  ;;
fujitsu-4.1)
  module purge
  module load fujitsu/1.2.26
  MAKE_OPTS='COMPILER=GNU MPI_COMPILER=mpifrt C_MPI_COMPILER=mpifcc'
  MAKE_OPTS+=' FLAGS_GNU="-Kfast,simd2,assume=memory_bandwidth"'
  # MAKE_OPTS+=' FLAGS_GNU="-Ofast -ffast-math -ffp-contract=fast -march=armv8.3-a+sve -funroll-loops"'
  MAKE_OPTS+=' CFLAGS_GNU="-Nclang -Ofast -ffast-math -ffp-contract=fast -march=armv8.3-a+sve -funroll-loops"'
  ;;
gcc-8.3)
  module purge
  module load openmpi/4.0.3/gcc-8.3
  MAKE_OPTS='COMPILER=GNU'
  MAKE_OPTS+=' FLAGS_GNU="-Ofast -ffast-math -ffp-contract=fast -march=armv8.3-a+sve -funroll-loops"'
  MAKE_OPTS+=' CFLAGS_GNU="-Ofast -ffast-math -ffp-contract=fast -march=armv8.3-a+sve -funroll-loops"'
  ;;
*)
  echo
  echo "Invalid compiler '$COMPILER'."
  usage
  exit 1
  ;;
esac

case "$MODEL" in
  omp|mpi)
    ;;
  kokkos)
    KOKKOS_PATH="$PWD/$(fetch_kokkos)"
    echo "Using KOKKOS_PATH='${KOKKOS_PATH}'"
    MAKE_OPTS+=" KOKKOS_PATH=${KOKKOS_PATH} ARCH=ARMv81 DEVICE=OpenMP"
    [[ "$COMPILER" =~ fujitsu- ]] && MAKE_OPTS+=" CXX=mpiFCC"
    SRC_DIR="$PWD/cloverleaf_kokkos"
    ;;
esac

# Handle actions
if [ "$ACTION" == "build" ]; then
  # Fetch source code
  fetch_src "$MODEL"

  rm -f "$RUN_DIR/$BENCHMARK_EXE"

  if ! eval make -C "$SRC_DIR" -B "$MAKE_OPTS" -j "$(nproc)"; then
    echo
    echo "Build failed."
    echo
    exit 1
  fi

  mkdir -p "$RUN_DIR"
  mv "$SRC_DIR/$BENCHMARK_EXE" "$RUN_DIR/"

elif [ "$ACTION" == "run" ]; then
  check_bin "$RUN_DIR/$BENCHMARK_EXE"
  bash "$SCRIPT_DIR/run.sh" |& tee "CloverLeaf-$CONFIG.out"
else
  echo
  echo "Invalid action (use 'build' or 'run')."
  echo
  exit 1
fi
