#!/bin/bash

DEFAULT_MODEL=omp
function usage() {
  echo
  echo "Usage: ./benchmark.sh build|run [MODEL]"
  echo
  echo "Valid models:"
  echo "  omp"
  echo "  kokkos"
  echo "  sycl"
  echo
  echo "The default programming model is '$DEFAULT_MODEL'."
  echo
}

# Process arguments
if [ $# -lt 1 ]; then
  usage
  exit 1
fi

ACTION=$1
MODEL=${2:-$DEFAULT_MODEL}
SCRIPT=$(realpath $0)
SCRIPT_DIR=$(realpath $(dirname $SCRIPT))
source ${SCRIPT_DIR}/../common.sh
export SRC_DIR=$PWD/CloverLeaf

module purge

export MODEL=$MODEL
case "$MODEL" in
omp)
  COMPILER="gcc-8.1"

  module load gcc/8.1.0 openmpi/3.0.3/gcc-8.1
  MAKE_OPTS='COMPILER=GNU'
  MAKE_OPTS+=' FLAGS_GNU="-Ofast -ffast-math -ffp-contract=fast -march=armv8-a -funroll-loops"'
  MAKE_OPTS+=' CFLAGS_GNU="-Ofast -ffast-math -ffp-contract=fast -march=armv8-a -funroll-loops"'

  export SRC_DIR=$PWD/CloverLeaf_ref

  BINARY="clover_leaf"
  ;;
kokkos)
  COMPILER="gcc-8.1"
  module load gcc/8.1.0 openmpi/3.0.3/gcc-8.1

  KOKKOS_PATH=$(pwd)/$(fetch_kokkos)
  echo "Using KOKKOS_PATH=${KOKKOS_PATH}"
  export SRC_DIR=$PWD/cloverleaf_kokkos
  MAKE_OPTS+="CXX=mpiCC  KOKKOS_PATH=${KOKKOS_PATH} ARCH=ARMv80 DEVICE=OpenMP"
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
  ;;
esac

export CONFIG="ampere"_"$COMPILER"_"$MODEL"
export BENCHMARK_EXE=CloverLeaf-$CONFIG
export RUN_DIR=$PWD/CloverLeaf-$CONFIG

if [ "$ACTION" == "build" ]; then

  fetch_src $MODEL

  build_bin "$MODEL" "$MAKE_OPTS" "$SRC_DIR" "$BINARY" "$RUN_DIR" "$BENCHMARK_EXE"

elif
  [ "$ACTION" == "run" ]
then
  check_bin $RUN_DIR/$BENCHMARK_EXE
  cd $RUN_DIR || exit
  bash "$SCRIPT_DIR/run.sh" CloverLeaf-$CONFIG.out
else
  echo
  echo "Invalid action (use 'build' or 'run')."
  echo
  exit 1
fi
