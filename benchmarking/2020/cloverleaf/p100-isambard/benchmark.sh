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
  echo "  opencl"
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
COMPILER=${2:-$DEFAULT_COMPILER}
MODEL=${3:-$DEFAULT_MODEL}
SCRIPT=$(realpath $0)
SCRIPT_DIR=$(realpath $(dirname $SCRIPT))
source ${SCRIPT_DIR}/../common.sh
export CONFIG="p100"_"$COMPILER"_"$MODEL"
export BENCHMARK_EXE=CloverLeaf-$CONFIG
export SRC_DIR=$PWD/CloverLeaf
export RUN_DIR=$PWD/CloverLeaf-$CONFIG

case "$MODEL" in
omp-target)
  module purge
  module load gcc/7.4.0 # newer versions of libstdc++
  module load shared pbspro craype-broadwell PrgEnv-cray
  module swap cce cce/10.0.0

  export SRC_DIR="$PWD/CloverLeaf-OpenMP4"
  MAKE_OPTS='-j16 COMPILER=CRAY MPI_F90=ftn MPI_C=cc'
  ;;
cuda)
 module purge
  module load shared pbspro
  module load gcc/6.1.0 craype-accel-nvidia60 cuda10.2/toolkit/10.2.89
  export SRC_DIR="$PWD/CloverLeaf_CUDA"
  MAKE_OPTS='-j16 COMPILER=CRAY NV_ARCH=PASCAL C_MPI_COMPILER=cc MPI_COMPILER=ftn'
  ;;
kokkos)
  module purge
  module load shared pbspro
  module load gcc/6.1.0 craype-accel-nvidia60 cuda10.2/toolkit/10.2.89

  NVCC=$(which nvcc)
  echo "Using NVCC=${NVCC}"
  CUDA_PATH=$(dirname $NVCC)/..

  KOKKOS_PATH=$(pwd)/$(fetch_kokkos)
  echo "Using KOKKOS_PATH=${KOKKOS_PATH}"

  MAKE_OPTS="CXX=CC"
  MAKE_OPTS+=" KOKKOS_PATH=${KOKKOS_PATH} ARCH=Pascal60 DEVICE=Cuda NVCC_WRAPPER=${KOKKOS_PATH}/bin/nvcc_wrapper"
  MAKE_OPTS+=' KOKKOS_CUDA_OPTIONS="enable_lambda"'
  MAKE_OPTS+=' EXTRA_INC="-I$CUDA_PATH/include/ -L$CUDA_PATH/lib64"'

  export SRC_DIR=$PWD/cloverleaf_kokkos
  BINARY="clover_leaf"
  ;;
acc)
  module purge
  module load shared pbspro
  module load craype-accel-nvidia60
  module load cuda10.2/toolkit/10.2.89
  module load pgi/compiler/19.10
  export SRC_DIR="$PWD/CloverLeaf-OpenACC"
  MAKE_OPTS='COMPILER=PGI C_MPI_COMPILER=mpicc MPI_F90=mpif90  FLAGS_PGI="-O3 -Mpreprocess -fast -acc -ta=tesla:cc60" CFLAGS_PGI="-O3 -ta=tesla:cc60" OMP_PGI=""'
  ;;
opencl)
  module swap "craype-$CRAY_CPU_TARGET" craype-broadwell
  module load craype-accel-nvidia60
  module load gcc/6.1.0
  module load openmpi/gcc-6.1.0/1.10.7
  export SRC_DIR="$PWD/CloverLeaf"
  NVCC=$(which nvcc)
  CUDA_PATH=$(dirname $NVCC)/..
  CUDA_INCLUDE=$CUDA_PATH/include
  MAKE_OPTS='COMPILER=GNU USE_OPENCL=1 EXTRA_INC="-I $CUDA_INCLUDE -I $CUDA_INCLUDE/CL -L$CUDA_PATH/lib64" EXTRA_PATH="-I $CUDA_INCLUDE -I $CUDA_INCLUDE/CL -L$CUDA_PATH/lib64"'
  mkdir -p $SRC_DIR/obj $SRC_DIR/mpiobj
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

  fetch_src $MODEL

  if [ "$MODEL" == "omp-target" ]; then
    # As of 21 Mar 2019, the linker command does not work with the Cray compiler (and possibly others too)
    sed -i '/-o clover_leaf/c\\t$(MPI_F90) $(FFLAGS) $(OBJ) $(LDLIBS) -o clover_leaf' "$SRC_DIR/Makefile"
  fi

  rm -f $RUN_DIR/$BENCHMARK_EXE

  if [ "$MODEL" == "sycl" ]; then
    cd $SRC_DIR || exit
    rm -rf build
    module load cmake/3.17.3
    cmake -Bbuild -H. -DCMAKE_BUILD_TYPE=Release $MAKE_OPTS
    cmake --build build --target clover_leaf --config Release -j $(nproc)
    mv build/$BINARY $BINARY
    cd $SRC_DIR/.. || exit
  else

    if ! eval make -C $SRC_DIR -B $MAKE_OPTS -j $(nproc); then
      echo
      echo "Build failed."
      echo
      exit 1
    fi

  fi

  mkdir -p $RUN_DIR
  mv $SRC_DIR/$BENCHMARK_EXE $RUN_DIR

elif [ "$ACTION" == "run" ]; then
  check_bin $RUN_DIR/$BENCHMARK_EXE
  qsub -N CloverLeaf-$CONFIG -o "CloverLeaf-$CONFIG.out" -V "$SCRIPT_DIR/run.job"
else
  echo
  echo "Invalid action (use 'build' or 'run')."
  echo
  exit 1
fi
