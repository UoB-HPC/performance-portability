# shellcheck shell=bash

set -eu
set -o pipefail

function usage() {
  echo
  echo "Usage: ./benchmark.sh build|run [MODEL] [COMPILER]"
  echo
  echo "Valid model and compiler options:"
  echo "  omp"
  echo "    arm-20.0"
  echo "    cce-10.0"
  echo "    gcc-9.3"
  echo
  echo "  kokkos"
  echo "    arm-20.0"
  echo "    cce-10.0"
  echo "    gcc-9.3"
  echo
  echo "  sycl"
  echo "    hipsycl-200527-gcc"
  echo
  echo "The default configuration is '$DEFAULT_MODEL $DEFAULT_COMPILER'."
  echo
}

# Process arguments
if [ $# -lt 1 ]; then
  usage
  exit 1
fi


action="$1"
export MODEL="${2:-$DEFAULT_MODEL}"
export COMPILER="${3:-$DEFAULT_COMPILER}"
export CONFIG="${PLATFORM}_${COMPILER}_${MODEL}"

export SRC_DIR="$PWD/bude-portability-benchmark"
export RUN_DIR="$PWD/bude-$CONFIG"
export BENCHMARK_EXE="bude_$CONFIG"

# Set up the environment
setup_env

# Setup model
case "$MODEL" in
  omp)
    SRC_DIR+="/openmp"
    RUN_DIR="$SRC_DIR"
    ;;

  kokkos)
    echo "$MODEL is not implemented" && exit 99
    ;;

  sycl)
    echo "$MODEL is not implemented" && exit 99
    ;;

  *)
    echo
    echo "Invalid model '$MODEL'."
    usage
    exit 1
    ;;
esac

# Fetch source
if [ ! -e bude-portability-benchmark/openmp/bude.c ]; then
  if ! git clone https://github.com/UoB-HPC/bude-portability-benchmark; then
    echo
    echo "Failed to fetch source code."
    echo
    exit 1
  fi
fi

cd "$SRC_DIR"

# Handle actions
if [ "$action" == "build" ]; then
  make clean
  rm -f "$BENCHMARK_EXE"

  if ! eval make -B "$MAKE_OPTS" -j; then
    echo
    echo "Build failed."
    echo
    exit 1
  fi
  mv bude "$BENCHMARK_EXE"
elif [ "$action" == "run" ]; then
  # Check binary exists
  if [ ! -x "$BENCHMARK_EXE" ]; then
    echo "Executable '$BENCHMARK_EXE' not found."
    echo "Use the 'build' action first."
    exit 1
  fi

  qsub -o "bude-$CONFIG.out" -N bude -V "$SCRIPT_DIR/run.job"
else
  echo
  echo "Invalid action (use 'build' or 'run')."
  echo
  exit 1
fi
