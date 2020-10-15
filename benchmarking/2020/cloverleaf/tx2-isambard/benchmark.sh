#!/bin/bash

DEFAULT_COMPILER=cce-10.0
DEFAULT_MODEL=omp
function usage() {
  echo
  echo "Usage: ./benchmark.sh build|run [MODEL] [COMPILER]"
  echo
  echo "Valid model and compiler options:"
  echo "  mpi | omp"
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

ACTION="$1"
export MODEL="${2:-$DEFAULT_MODEL}"
export COMPILER="${3:-$DEFAULT_COMPILER}"
SCRIPT="$(realpath "$0")"
SCRIPT_DIR="$(realpath "$(dirname "$SCRIPT")")"
source "${SCRIPT_DIR}/../common.sh"
export CONFIG="tx2_${COMPILER}_${MODEL}"
export SRC_DIR="$PWD/CloverLeaf_ref"
export RUN_DIR="$PWD/CloverLeaf-$CONFIG"
export BENCHMARK_EXE="clover_leaf"

# Set up the environment
case "$COMPILER" in
  cce-10.0)
    [ -z "$CRAY_CPU_TARGET" ] && module load craype-arm-thunderx2
    module swap cce cce/10.0.1
    MAKE_OPTS='COMPILER=ARM MPI_COMPILER=ftn C_MPI_COMPILER=cc FLAGS_ARM="-em -ra"'
    ;;
  gcc-9.3)
    module swap PrgEnv-{cray,gnu}
    module swap gcc gcc/9.3.0
    MAKE_OPTS='COMPILER=GNU MPI_COMPILER=cc C_MPI_COMPILER=cc'
    MAKE_OPTS+=' FLAGS_GNU="-Ofast -ffast-math -ffp-contract=fast -mcpu=thunderx2t99 -funroll-loops"'
    MAKE_OPTS+=' CFLAGS_GNU="-Ofast -ffast-math -ffp-contract=fast -mcpu=thunderx2t99 -funroll-loops"'
    ;;
  arm-20.0)
    module swap PrgEnv-{cray,allinea}
    module swap allinea allinea/20.0.0.0
    MAKE_OPTS='COMPILER=GNU MPI_COMPILER=ftn C_MPI_COMPILER=cc'
    MAKE_OPTS+=' FLAGS_GNU="-Ofast -ffast-math -ffp-contract=fast -mcpu=thunderx2t99 -funroll-loops"'
    MAKE_OPTS+=' CFLAGS_GNU="-Ofast -ffast-math -ffp-contract=fast -mcpu=thunderx2t99 -funroll-loops"'
    ;;
  hipsycl-200527-gcc)
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

case "$MODEL" in
  omp)
    export SRC_DIR="$PWD/CloverLeaf_ref"
    ;;

  kokkos)
    KOKKOS_PATH="$PWD/$(fetch_kokkos)"
    echo "Using KOKKOS_PATH='${KOKKOS_PATH}'"
    MAKE_OPTS+=" CXX=CC KOKKOS_PATH=${KOKKOS_PATH} ARCH=ARMv8-TX2 DEVICE=OpenMP"
    [[ "$COMPILER" =~ cce- ]] && MAKE_OPTS+=" KOKKOS_INTERNAL_OPENMP_FLAG=-fopenmp"
    SRC_DIR="$PWD/cloverleaf_kokkos"
    ;;

  sycl)
    HIPSYCL_PATH="$(realpath "$(dirname "$(which syclcc)")"/..)"
    echo "Using HIPSYCL_PATH=${HIPSYCL_PATH}"
    MAKE_OPTS+=" -DHIPSYCL_INSTALL_DIR=${HIPSYCL_PATH} -DSYCL_RUNTIME=HIPSYCL"
    MAKE_OPTS+=" -DMPI_AS_LIBRARY=ON -DMPI_C_LIB_DIR=${CRAY_MPICH_DIR}/lib -DMPI_C_INCLUDE_DIR=${CRAY_MPICH_DIR}/include -DMPI_C_LIB=mpich"
    MAKE_OPTS+=" -DCXX_EXTRA_FLAGS=-mcpu=native"

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
    module load cmake/3.17.3
    cmake -Bbuild -H. -DCMAKE_BUILD_TYPE=Release $MAKE_OPTS
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
  qsub -o "CloverLeaf-$CONFIG.out" -N cloverleaf -V "$SCRIPT_DIR/run.job"
else
  echo
  echo "Invalid action (use 'build' or 'run')."
  echo
  exit 1
fi
