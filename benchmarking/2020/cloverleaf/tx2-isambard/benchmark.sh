#!/bin/bash

DEFAULT_COMPILER=cce-10.0
DEFAULT_MODEL=omp
function usage() {
  echo
  echo "Usage: ./benchmark.sh build|run [COMPILER] [MODEL]"
  echo
  echo "Valid compilers:"
  echo "  cce-10.0"
  echo "  gcc-9.2"
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

ACTION=$1
COMPILER=${2:-$DEFAULT_COMPILER}
MODEL=${3:-$DEFAULT_MODEL}
SCRIPT=$(realpath $0)
SCRIPT_DIR=$(realpath $(dirname $SCRIPT))
source ${SCRIPT_DIR}/../common.sh
export CONFIG="tx2"_"$COMPILER"_"$MODEL"
export BENCHMARK_EXE=CloverLeaf-$CONFIG
export SRC_DIR=$PWD/CloverLeaf
export RUN_DIR=$PWD/CloverLeaf-$CONFIG

# Set up the environment
case "$COMPILER" in
cce-10.0)
  module purge
  module load alps PrgEnv-cray cray-mpich/7.7.12
  [ -z "$CRAY_CPU_TARGET" ] && module load craype-arm-thunderx2
  module swap cce cce/10.0.1
  MAKE_OPTS='COMPILER=CRAY MPI_COMPILER=ftn C_MPI_COMPILER=cc'
  ;;
gcc-9.2)
  module purge
  module load alps PrgEnv-gnu cray-mpich/7.7.12
  module swap gcc gcc/9.2.0
  # PrgEnv-gnu handles mpicc/mpifort for us, so use CC
  MAKE_OPTS='COMPILER=GNU MPI_COMPILER=cc C_MPI_COMPILER=cc'
  MAKE_OPTS+=' FLAGS_GNU="-Ofast -ffast-math -ffp-contract=fast -mcpu=thunderx2t99 -funroll-loops"'
  MAKE_OPTS+=' CFLAGS_GNU="-Ofast -ffast-math -ffp-contract=fast -mcpu=thunderx2t99 -funroll-loops"'
  export OMP_PROC_BIND=spread
  ;;
allinea-20.0)
  module purge
  module load alps PrgEnv-allinea cray-mpich/7.7.12
  #  module swap allinea allinea/20.0.0.0
  MAKE_OPTS='COMPILER=GNU MPI_COMPILER=ftn C_MPI_COMPILER=cc'
  MAKE_OPTS+=' FLAGS_GNU="-Ofast -ffast-math -ffp-contract=fast -mcpu=thunderx2t99 -funroll-loops"'
  MAKE_OPTS+=' CFLAGS_GNU="-Ofast -ffast-math -ffp-contract=fast -mcpu=thunderx2t99 -funroll-loops"'
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
  export SRC_DIR=$PWD/CloverLeaf_ref
  MAKE_OPTS+=' OMP_CRAY="-h omp"'
  BINARY="clover_leaf"
  ;;
kokkos)
  KOKKOS_PATH=$(pwd)/$(fetch_kokkos)
  echo "Using KOKKOS_PATH=${KOKKOS_PATH}"
  export SRC_DIR=$PWD/cloverleaf_kokkos
  MAKE_OPTS="CXX=CC  KOKKOS_PATH=${KOKKOS_PATH} ARCH=ARMv8-TX2 DEVICE=OpenMP"
  BINARY="clover_leaf"
  ;;
esac

# Handle actions
if [ "$ACTION" == "build" ]; then
  # Fetch source code
  fetch_src $MODEL

  rm -f $RUN_DIR/$BENCHMARK_EXE

  if ! eval make -C $SRC_DIR -B $MAKE_OPTS -j $(nproc); then
    echo
    echo "Build failed."
    echo
    exit 1
  fi

  # Rename binary
  mkdir -p $RUN_DIR
  mv $SRC_DIR/$BINARY $RUN_DIR/$BENCHMARK_EXE

elif [ "$ACTION" == "run" ]; then
  check_bin $RUN_DIR/$BENCHMARK_EXE
  qsub -o CloverLeaf-$CONFIG.out -N cloverleaf -V $SCRIPT_DIR/run.job
else
  echo
  echo "Invalid action (use 'build' or 'run')."
  echo
  exit 1
fi
