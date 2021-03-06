#!/bin/bash

set -eu
DEFAULT_MODEL=cuda
function usage() {
  echo
  echo "Usage: ./benchmark.sh build|run [MODEL]"
  echo
  echo
  echo "Valid models:"
  echo "  omp-target"
  echo "  cuda"
  echo "  kokkos"
  echo "  acc"
  echo "  ocl"
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
module load shared pbspro
module load craype-broadwell

export MODEL=$MODEL
case "$MODEL" in
cuda)
  COMPILER=cce-10.0
  module load gcc/7.4.0 # newer versions of libstdc++
  module load PrgEnv-cray craype-broadwell craype-accel-nvidia60
  module swap cce cce/10.0.0

  export SRC_DIR="$PWD/CloverLeaf_CUDA"
  MAKE_OPTS='-j16 COMPILER=CRAY NV_ARCH=PASCAL C_MPI_COMPILER=cc MPI_COMPILER=ftn'
  BINARY="clover_leaf"
  ;;
kokkos)
  COMPILER=gcc-6.1
  module load gcc/6.1.0
  module load openmpi/gcc-6.1.0/1.10.7
  module load craype-accel-nvidia60 cuda10.2/toolkit/10.2.89

  NVCC=$(which nvcc)
  echo "Using NVCC=${NVCC}"
  CUDA_PATH=$(dirname $NVCC)/..

  KOKKOS_PATH=$(pwd)/$(fetch_kokkos)
  echo "Using KOKKOS_PATH=${KOKKOS_PATH}"

  MAKE_OPTS="CXX=${KOKKOS_PATH}/bin/nvcc_wrapper"
  MAKE_OPTS+=" KOKKOS_PATH=${KOKKOS_PATH} ARCH=Pascal60 DEVICE=Cuda NVCC_WRAPPER=${KOKKOS_PATH}/bin/nvcc_wrapper"
  MAKE_OPTS+=' KOKKOS_CUDA_OPTIONS="enable_lambda"'
  MAKE_OPTS+=' OPTIONS="-lmpi -O3 "'
  export SRC_DIR=$PWD/cloverleaf_kokkos
  BINARY="clover_leaf"
  ;;
acc)
  COMPILER=pgi-19.10
  module load craype-accel-nvidia60
  module load cuda10.2/toolkit/10.2.89
  module load pgi/compiler/19.10 pgi/openmpi/3.1.3

  export SRC_DIR="$PWD/CloverLeaf-OpenACC"
  MAKE_OPTS='COMPILER=PGI C_MPI_COMPILER=mpicc MPI_F90=mpif90  FLAGS_PGI="-O3 -Mpreprocess -fast -acc -ta=tesla:cc60" CFLAGS_PGI="-O3 -ta=tesla:cc60" OMP_PGI=""'
  BINARY="clover_leaf"
  ;;
ocl)
  COMPILER=gcc-6.1
  module load gcc/6.1.0
  module load openmpi/gcc-6.1.0/1.10.7
  module load craype-accel-nvidia60 cuda10.2/toolkit/10.2.89

  export SRC_DIR="$PWD/CloverLeaf_OpenCL"
  CUDA_PATH=$(dirname $(which nvcc))/..
  CUDA_INCLUDE=$CUDA_PATH/include

  MAKE_OPTS='COMPILER=GNU USE_OPENCL=1 OCL_VENDOR=NVIDIA'
  MAKE_OPTS+=" COPTIONS='-DCL_TARGET_OPENCL_VERSION=110 -DOCL_IGNORE_PLATFORM -std=c++98'  OPTIONS='-lstdc++ -cpp -lOpenCL -L/home/br-jprice/modules/openmpi/gcc-6.1.0/1.10.7/lib -lmpi_cxx -lmpi'"
  MAKE_OPTS+=' EXTRA_INC="-I $CUDA_INCLUDE -I $CUDA_INCLUDE/CL -L$CUDA_PATH/lib64"'
  MAKE_OPTS+=' EXTRA_PATH="-I $CUDA_INCLUDE -I $CUDA_INCLUDE/CL -L$CUDA_PATH/lib64"'

  BINARY="clover_leaf"
  ;;
sycl)
  COMPILER=hipsycl-trunk
  module load gcc/8.2.0
  module load openmpi/gcc-6.1.0/1.10.7
  module load craype-accel-nvidia60 cuda10.2/toolkit/10.2.89
  module load hipsycl/trunk

  HIPSYCL_PATH=$(realpath $(dirname $(which syclcc))/..)
  echo "Using HIPSYCL_PATH=${HIPSYCL_PATH}"

  CRAY_MPICH_DIR=/home/br-jprice/modules/openmpi/gcc-6.1.0/1.10.7
  MAKE_OPTS+=" -DHIPSYCL_INSTALL_DIR=${HIPSYCL_PATH} -DSYCL_RUNTIME=HIPSYCL -DCMAKE_CXX_COMPILER=g++ -DCMAKE_C_COMPILER=gcc"
  MAKE_OPTS+=" -DCXX_EXTRA_FLAGS=-mtune=native -DHIPSYCL_PLATFORM=cuda -DHIPSYCL_GPU_ARCH=sm_60"

  BINARY="clover_leaf"
  export SRC_DIR=$PWD/cloverleaf_sycl
  ;;
omp-target)
  COMPILER=cce-10.0
  module load gcc/7.4.0 # newer versions of libstdc++
  module load PrgEnv-cray craype-broadwell craype-accel-nvidia60 
  module swap cce cce/10.0.0
  module load cmake/3.18.3
# set -x
  # MAKE_OPTS+=" -DCMAKE_C_COMPILER=cc -DCMAKE_CXX_COMPILER=CC"
  # MAKE_OPTS+=" -DOMP_ALLOW_HOST=OFF"
  # MAKE_OPTS+=" -DOMP_OFFLOAD_FLAGS='-fopenmp-targets=nvptx64 -Xopenmp-target -march=sm_60' "

  MAKE_OPTS=(
    "-DCMAKE_C_COMPILER=cc" 
    "-DCMAKE_CXX_COMPILER=CC" 
    # "-DOMP_ALLOW_HOST=OFF" 
    "-DOMP_OFFLOAD_FLAGS='-fopenmp-targets=nvptx64 -Xopenmp-target -march=sm_60'"
  )


  BINARY="clover_leaf"
  export SRC_DIR=$PWD/cloverleaf_openmp_target
  ;;    
*)
  echo
  echo "Invalid model '$MODEL'."
  usage
  exit 1
  ;;
esac

export CONFIG="p100"_"$COMPILER"_"$MODEL"
export BENCHMARK_EXE=CloverLeaf-$CONFIG
export RUN_DIR=$PWD/CloverLeaf-$CONFIG

# Handle actions
if [ "$ACTION" == "build" ]; then

  fetch_src $MODEL

  #  if [ "$MODEL" == "omp-target" ]; then
  #    # As of 21 Mar 2019, the linker command does not work with the Cray compiler (and possibly others too)
  #    sed -i '/-o clover_leaf/c\\t$(MPI_F90) $(FFLAGS) $(OBJ) $(LDLIBS) -o clover_leaf' "$SRC_DIR/Makefile"
  #  fi


  if [ "$MODEL" == "omp-target" ]; then
    # Passing quoted string args to cmake requires an array hence the special case here
    cd $SRC_DIR || exit
    rm -rf build
    module load cmake/3.12.3
    cmake -Bbuild -H. -DCMAKE_BUILD_TYPE=Release "${MAKE_OPTS[@]}" 
    cmake --build build --target clover_leaf --config Release -j $(nproc)
    mv build/$BINARY $BINARY
    cd $SRC_DIR/.. || exit
    mkdir -p $RUN_DIR
    mv $SRC_DIR/$BINARY $RUN_DIR/$BENCHMARK_EXE
  else 
    build_bin "$MODEL" "$MAKE_OPTS" "$SRC_DIR" "$BINARY" "$RUN_DIR" "$BENCHMARK_EXE"
  fi
elif
  [ "$ACTION" == "run" ]
then
  check_bin $RUN_DIR/$BENCHMARK_EXE
  qsub -N CloverLeaf-$CONFIG -o "CloverLeaf-$CONFIG.out" -V "$SCRIPT_DIR/run.job"
else
  echo
  echo "Invalid action (use 'build' or 'run')."
  echo
  exit 1
fi
