#!/bin/bash

DEFAULT_COMPILER=cce-10.0
DEFAULT_MODEL=omp
function usage() {
  echo
  echo "Usage: ./benchmark.sh build|run [COMPILER] [MODEL]"
  echo
  echo "Valid compilers:"
  echo "  cce-10.0"
  echo "  gcc-9.3"
  echo "  allinea-20.0"
  echo
  echo "Valid models:"
  echo " omp"
  echo " kokkos"
  echo
  echo "The default configuration is '$DEFAULT_COMPILER'."
  echo "The default programming model is '$DEFAULT_MODEL'."
  echo
}

# Process arguments
if [ $# -lt 1 ]; then
  usage
  exit 1
fi

ACTION="$1"
COMPILER="${2:-$DEFAULT_COMPILER}"
MODEL="${3:-$DEFAULT_MODEL}"
SCRIPT="$(realpath "$0")"
SCRIPT_DIR="$(realpath "$(dirname "$SCRIPT")")"
source "${SCRIPT_DIR}/../common.sh"
export CONFIG="tx2_${COMPILER}_${MODEL}"
export BENCHMARK_EXE="CloverLeaf-$CONFIG"
export SRC_DIR="$PWD/CloverLeaf"
export RUN_DIR="$PWD/CloverLeaf-$CONFIG"

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
allinea-20.0)
  module swap PrgEnv-{cray,allinea}
  module swap allinea allinea/20.0.0.0
  MAKE_OPTS='COMPILER=GNU MPI_COMPILER=ftn C_MPI_COMPILER=cc'
  MAKE_OPTS+=' FLAGS_GNU="-Ofast -ffast-math -ffp-contract=fast -mcpu=thunderx2t99 -funroll-loops"'
  MAKE_OPTS+=' CFLAGS_GNU="-Ofast -ffast-math -ffp-contract=fast -mcpu=thunderx2t99 -funroll-loops"'
  ;;
hipsycl-200527-gcc)
  module purge
  module load alps PrgEnv-gnu cray-mpich/7.7.12
  module load hipsycl/gcc/200527
  ;;
hipsycl-200527-cce)
  module purge
  module load alps PrgEnv-cray cray-mpich/7.7.12
  module load hipsycl/cce/200527
  ;;
hipsycl-200527simd-gcc)
  module purge
  module load alps PrgEnv-gnu cray-mpich/7.7.12
  module load hipsycl/gcc/200527_simd
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
  BINARY="clover_leaf"
  ;;
kokkos)
  KOKKOS_PATH=$(pwd)/$(fetch_kokkos)
  echo "Using KOKKOS_PATH=${KOKKOS_PATH}"
  export SRC_DIR=$PWD/cloverleaf_kokkos
  MAKE_OPTS+="CXX=CC  KOKKOS_PATH=${KOKKOS_PATH} ARCH=ARMv8-TX2 DEVICE=OpenMP"
  BINARY="clover_leaf"
  ;;
sycl)

  HIPSYCL_PATH=$(realpath $(dirname $(which syclcc))/..)
  echo "Using HIPSYCL_PATH=${HIPSYCL_PATH}"
  MAKE_OPTS+=" -DHIPSYCL_INSTALL_DIR=${HIPSYCL_PATH} -DSYCL_RUNTIME=HIPSYCL"
  MAKE_OPTS+=" -DMPI_AS_LIBRARY=ON -DMPI_C_LIB_DIR=${CRAY_MPICH_DIR}/lib -DMPI_C_INCLUDE_DIR=${CRAY_MPICH_DIR}/include -DMPI_C_LIB=mpich"
  MAKE_OPTS+=" -DCXX_EXTRA_FLAGS=-mtune=native"

  BINARY="clover_leaf"
  export SRC_DIR=$PWD/cloverleaf_sycl
  export DEVICE_ARGS="--device 1"
  ;;
esac

# Handle actions
if [ "$ACTION" == "build" ]; then
  # Fetch source code
  fetch_src "$MODEL"

  rm -f "$RUN_DIR/$BENCHMARK_EXE"

  if [ "$MODEL" == "sycl" ]; then
    cd $SRC_DIR || exit
    rm -rf build
    module load cmake/3.17.3
    cmake -Bbuild -H. -DCMAKE_BUILD_TYPE=Release $MAKE_OPTS
    cmake --build build --target clover_leaf --config Release -j $(nproc)
    mv build/$BINARY $BINARY
    cd $SRC_DIR/.. || exit
  else

    if ! eval make -C "$SRC_DIR" -B "$MAKE_OPTS" -j "$(nproc)"; then
      echo
      echo "Build failed."
      echo
      exit 1
    fi

  fi

  # Rename binary
  mkdir -p "$RUN_DIR"
  mv "$SRC_DIR/$BINARY" "$RUN_DIR/$BENCHMARK_EXE"

elif [ "$ACTION" == "run" ]; then
  check_bin "$RUN_DIR/$BENCHMARK_EXE"
  qsub -o "CloverLeaf-$CONFIG.out" -N cloverleaf -V "$SCRIPT_DIR/run.job"
else
  echo
  echo "Invalid action (use 'build' or 'run')."
  echo
  exit 1
fi
