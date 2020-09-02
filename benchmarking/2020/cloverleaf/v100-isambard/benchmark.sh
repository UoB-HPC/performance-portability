#!/bin/bash

set -eu

DEFAULT_MODEL=cuda
function usage() {
  echo
  echo "Usage: ./benchmark.sh build|run [MODEL]"
  echo
  echo "Valid models:"
  echo "  omp-target"
  echo "  cuda"
  echo "  kokkos"
  echo "  acc"
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
export MODEL=${2:-$DEFAULT_MODEL}
SCRIPT=$(realpath $0)
SCRIPT_DIR=$(realpath $(dirname $SCRIPT))
source ${SCRIPT_DIR}/../common.sh
export CONFIG="v100"_"$MODEL"
export BENCHMARK_EXE=CloverLeaf-$CONFIG
export SRC_DIR=$PWD/CloverLeaf
export RUN_DIR=$PWD/CloverLeaf-$CONFIG

module use /lustre/projects/bristol/modules-power/modulefiles
module load cuda/10.0
case "$MODEL" in
omp-target)
  module load llvm/trunk
  module load gcc/8.1.0
  module load openmpi/3.0.2/gcc8
  export SRC_DIR="$PWD/CloverLeaf-OpenMP4"
  export OMPI_CC=clang OMPI_FC=gfortran
  MAKE_OPTS='-j20 COMPILER=GNU MPI_F90=mpif90 MPI_C=mpicc MPI_LD=mpicc'
  MAKE_OPTS="$MAKE_OPTS FLAGS_GNU='-O3 -mcpu=power9'"
  MAKE_OPTS="$MAKE_OPTS CFLAGS_GNU='-O3 -fopenmp -fopenmp-targets=nvptx64-nvidia-cuda -Xopenmp-target -march=sm_70' LDLIBS='-lrt -lm -lgfortran -lgomp -lmpi_mpifh'"
  MAKE_OPTS="$MAKE_OPTS LDFLAGS='-O3 -fopenmp -fopenmp-targets=nvptx64-nvidia-cuda -Xopenmp-target -march=sm_70'"
  ;;
cuda)
  module load cuda/10.0
  module load mpi/openmpi-ppc64le
  source /opt/rh/devtoolset-7/enable
  export SRC_DIR="$PWD/CloverLeaf_CUDA"
  MAKE_OPTS="-j20 COMPILER=GNU NV_ARCH=VOLTA CODEGEN_VOLTA='-gencode arch=compute_70,code=sm_70'"
  BINARY="clover_leaf"
  ;;
kokkos)
  module load kokkos/volta
  module load openmpi/3.0.2/gcc8
  export SRC_DIR="$PWD/cloverleaf_kokkos"
  MAKE_OPTS='-j -f Makefile.gpu'
  ;;
acc)
  module load pgi/compiler/19.10
  export PATH=/opt/pgi/linuxpower/18.10/mpi/openmpi/bin/:$PATH
  export SRC_DIR="$PWD/CloverLeaf-OpenACC"
  MAKE_OPTS='COMPILER=PGI C_MPI_COMPILER=mpicc MPI_F90=mpif90 FLAGS_PGI="-O3 -Mpreprocess -fast -acc -ta=tesla:cc70" CFLAGS_PGI="-O3 -ta=tesla:cc70" OMP_PGI=""'
  ;;
*)
  echo
  echo "Invalid model '$MODEL'."
  usage
  exit 1
  ;;
esac

# Handle actions
if [ "$ACTION" == "build" ]; then
  # Fetch source code
  fetch_src "$MODEL"

  # Perform build
  rm -f $RUN_DIR/$BENCHMARK_EXE

  # Perform build
  build_bin "$MODEL" "$MAKE_OPTS" "$SRC_DIR" "$BINARY" "$RUN_DIR" "$BENCHMARK_EXE"

elif [ "$ACTION" == "run" ]; then
    check_bin $RUN_DIR/$BENCHMARK_EXE
    #cd $RUN_DIR || exit
    bash "$SCRIPT_DIR/run.sh"
else
  echo
  echo "Invalid action (use 'build' or 'run')."
  echo
  exit 1
fi

