#!/bin/bash

DEFAULT_COMPILER=gcc-9.3
DEFAULT_MODEL=mpi
function usage() {
  echo
  echo "Usage: ./benchmark.sh build|run [MODEL] [COMPILER]"
  echo
  echo "Valid model and compiler options:"
  echo "  mpi | omp"
  echo "    arm-20.2"
  echo "    gcc-8.3"
  echo "    gcc-9.3"
  echo
  echo "  kokkos"
  echo "    arm-20.2"
  echo "    gcc-8.3"
  echo "    gcc-9.3"
  echo
  echo "  sycl"
  echo "    hipsycl-200902-gcc"
  echo "    hipsycl-200902-llvm"
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
export CONFIG="graviton2_${COMPILER}_${MODEL}"
export SRC_DIR="$PWD/CloverLeaf_ref"
export RUN_DIR="$PWD/CloverLeaf-$CONFIG"
export BENCHMARK_EXE="clover_leaf"

# Set up the environment
module purge
module use /mnt/shared/software/modulesfiles
case "$COMPILER" in
  arm-20.2)
    module load arm/20.2
    module load openmpi/4.0.3/arm-20.2
    MAKE_OPTS='COMPILER=ARM'
    MAKE_OPTS+=' FLAGS_ARM="-Ofast -ffast-math -ffp-contract=fast -mcpu=neoverse-n1 -funroll-loops"'
    MAKE_OPTS+=' CFLAGS_ARM="-Ofast -ffast-math -ffp-contract=fast -mcpu=neoverse-n1 -funroll-loops"'
    ;;
  gcc-8.3)
    module load openmpi/4.0.3/gcc-8.3
    MAKE_OPTS='COMPILER=GNU'
    MAKE_OPTS+=' FLAGS_GNU="-Ofast -ffast-math -ffp-contract=fast -march=armv8.2-a -funroll-loops"'
    MAKE_OPTS+=' CFLAGS_GNU="-Ofast -ffast-math -ffp-contract=fast -march=armv8.2-a -funroll-loops"'
    ;;
  gcc-9.3)
    module load gcc/9.3
    module load openmpi/4.0.3/gcc-8.3
    MAKE_OPTS='COMPILER=GNU'
    MAKE_OPTS+=' FLAGS_GNU="-Ofast -ffast-math -ffp-contract=fast -mcpu=neoverse-n1 -funroll-loops"'
    MAKE_OPTS+=' CFLAGS_GNU="-Ofast -ffast-math -ffp-contract=fast -mcpu=neoverse-n1 -funroll-loops"'
    ;;
  hipsycl-200902-gcc)
    module load hipsycl/200902-gcc
    module load openmpi/4.0.3/gcc-8.3
    MAKE_OPTS+=" -DCXX_EXTRA_FLAGS=-march=armv8.2-a"
    ;;
  hipsycl-200902-llvm)
    module load hipsycl/200902-llvm
    module load openmpi/4.0.3/arm-20.2
    export CC=clang CXX=clang++
    MAKE_OPTS+=" -DCXX_EXTRA_FLAGS=-mcpu=neoverse-n1"
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
    SRC_DIR="$PWD/cloverleaf_kokkos"
    ;;

  sycl)
    HIPSYCL_PATH="$(realpath "$(dirname "$(which syclcc)")"/..)"
    echo "Using HIPSYCL_PATH=${HIPSYCL_PATH}"
    MAKE_OPTS+=" -DHIPSYCL_INSTALL_DIR=${HIPSYCL_PATH} -DSYCL_RUNTIME=HIPSYCL"

    SRC_DIR="$PWD/cloverleaf_sycl"
    ;;
esac

# Handle actions
if [ "$ACTION" == "build" ]; then
  # Fetch source code
  fetch_src "$MODEL"

  rm -f "$RUN_DIR/$BENCHMARK_EXE"
  mkdir -p "$RUN_DIR"

  if [ "$MODEL" == "sycl" ]; then
    ( cd "$SRC_DIR" || exit 1
    rm -rf build
    module load cmake/3.18.2
    CXXFLAGS='-O3 -fopenmp' cmake -Bbuild -H. -DCMAKE_BUILD_TYPE=Release $MAKE_OPTS
    cmake --build build --target clover_leaf --config Release -j $(nproc)
    mv "build/$BENCHMARK_EXE" "$RUN_DIR/" )
  else
    if ! eval make -C "$SRC_DIR" -B "$MAKE_OPTS" -j "$(nproc)"; then
      echo
      echo "Build failed."
      echo
      exit 1
    fi

    mv "$SRC_DIR/$BENCHMARK_EXE" "$RUN_DIR/"
  fi

elif [ "$ACTION" == "run" ]; then
  check_bin "$RUN_DIR/$BENCHMARK_EXE"
  bash "$SCRIPT_DIR/run.sh" |& tee "CloverLeaf-$CONFIG.out"
else
  echo
  echo "Invalid action (use 'build' or 'run')."
  echo
  exit 1
fi
