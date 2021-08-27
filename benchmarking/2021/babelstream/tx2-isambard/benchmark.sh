#!/bin/bash

set -eu

if ! grep -q bristol/modules-arm-phase2/ <<<"$MODULEPATH"; then
    module use /lustre/projects/bristol/modules-arm-phase2/modulefiles
fi

DEFAULT_COMPILER=cce-10.0
DEFAULT_MODEL=omp
function usage() {
  echo
  echo "Usage: ./benchmark.sh build|run|run-large [COMPILER] [MODEL]"
  echo
  echo "Valid compilers:"
  echo "  cce-10.0"
  echo "  gcc-9.2"
  echo "  arm-20.0"
  echo "  llvm-11.0"
  echo "  hipsycl-200527-gcc"
  echo "  hipsycl-200527-cce"
  echo "  hipsycl-200527simd-gcc"
  echo "  julia-1.6.2"
  echo
  echo
  echo "Valid models:"
  echo "  omp"
  echo "  kokkos"
  echo "  sycl"
  echo "  ocl"
  echo "  julia-ka"
  echo "  julia-threaded"
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
export BENCHMARK_EXE=BabelStream-$CONFIG
export SRC_DIR=$PWD/BabelStream
export RUN_DIR=$PWD/BabelStream-$CONFIG

# Set up the environment
case "$COMPILER" in
julia-1.6.2)
  # module purge
  module load julia/1.6.2
  ;;
cce-10.0)
  module purge
  module load alps PrgEnv-cray
  [ -z "$CRAY_CPU_TARGET" ] && module load craype-arm-thunderx2
  module swap cce cce/10.0.1
  MAKE_OPTS="COMPILER=CRAY TARGET=CPU"
  ;;
gcc-9.2)
  module purge
  module load alps PrgEnv-gnu
  module swap gcc gcc/9.2.0
  MAKE_OPTS="COMPILER=GNU TARGET=CPU"
  export OMP_PROC_BIND=spread
  ;;
arm-20.0)
  module purge
  module load alps PrgEnv-allinea
  #  module swap allinea allinea/20.0.0.0
  MAKE_OPTS="COMPILER=ARMCLANG TARGET=CPU"
  export OMP_PROC_BIND=spread
  ;;
llvm-11.0)
  module load llvm/11.0.0
  MAKE_OPTS="COMPILER=CLANG TARGET=CPU OMP_CLANG_CPU=-fopenmp"
  ;;
hipsycl-200527-gcc)
  module purge
  module load alps PrgEnv-gnu
  module load hipsycl/gcc/200527
  MAKE_OPTS="COMPILER=HIPSYCL TARGET=CPU"
  ;;
hipsycl-200527-cce)
  module purge
  module load alps PrgEnv-cray
  module load hipsycl/cce/200527
  MAKE_OPTS="COMPILER=HIPSYCL TARGET=CPU"
  ;;
hipsycl-200527simd-gcc)
  module purge
  module load alps PrgEnv-gnu
  module load hipsycl/gcc/200527_simd
  MAKE_OPTS="COMPILER=HIPSYCL TARGET=CPU"
  ;;
*)
  echo
  echo "Invalid compiler '$COMPILER'."
  usage
  exit 1
  ;;
esac

case "$MODEL" in
  julia-ka)
    export JULIA_BACKEND="KernelAbstractions"
    JULIA_ENTRY="src/KernelAbstractionsStream.jl"
    BENCHMARK_EXE=$JULIA_ENTRY
    ;;
  julia-threaded)
    export JULIA_BACKEND="Threaded"
    JULIA_ENTRY="src/ThreadedStream.jl"
    BENCHMARK_EXE=$JULIA_ENTRY
    ;;
esac


export MODEL="$MODEL"
# Handle actions
if [ "$ACTION" == "build" ]; then

  # Fetch source code
  fetch_src

  # Perform build
  rm -f $RUN_DIR/$BENCHMARK_EXE

  # Select Makefile to use
  case "$MODEL" in
  julia-*)
    # nothing to do
    ;;
  omp)
    #    module load kokkos/3.1.1/cce-9.1
    MAKE_FILE="OpenMP.make"
    BINARY="omp-stream"
    ;;
  kokkos)
    KOKKOS_PATH=$(pwd)/$(fetch_kokkos)
    echo "Using KOKKOS_PATH=${KOKKOS_PATH}"
    MAKE_FILE="Kokkos.make"
    BINARY="kokkos-stream"
    MAKE_OPTS+=" KOKKOS_PATH=${KOKKOS_PATH} ARCH=ARMv8-TX2 DEVICE=OpenMP"
    export OMP_PROC_BIND=spread
    ;;
  sycl)
    HIPSYCL_PATH=$(realpath $(dirname $(which syclcc))/..)
    echo "Using HIPSYCL_PATH=${HIPSYCL_PATH}"
    MAKE_OPTS+=" SYCL_SDK_DIR=${HIPSYCL_PATH}"
    MAKE_FILE="SYCL.make"
    BINARY="sycl-stream"
    ;;
  ocl)
    if [ "$COMPILER" != "llvm-10.0" ]; then
      echo
      echo " Must use llvm-10.0 with ocl"
      echo
      stop
    fi
    module load pocl/1.5
    MAKE_FILE="OpenCL.make"
    BINARY="ocl-stream"
    ;; 
  *)
    echo
    echo "Invalid model '$MODEL'."
    exit 1
    ;;   
  esac

  mkdir -p $RUN_DIR
  
  if [ -z ${JULIA_ENTRY+x} ]; then
    if ! eval make -f $MAKE_FILE -C $SRC_DIR -B $MAKE_OPTS -j $(nproc); then
      echo
      echo "Build failed."
      echo
      exit 1
    fi
    # Rename binary
    mv $SRC_DIR/$BINARY $RUN_DIR/$BENCHMARK_EXE
  else 
    cp -R "$SRC_DIR/JuliaStream.jl/." $RUN_DIR/
  fi

elif [ "$ACTION" == "run" ]; then
  if [ "$MODEL" == "ocl" ]; then
    module load pocl/1.5
  fi
  check_bin $RUN_DIR/$BENCHMARK_EXE
  qsub -o BabelStream-$CONFIG.out -N babelstream -V $SCRIPT_DIR/run.job
elif [ "$ACTION" == "run-large" ]; then
  if [ "$MODEL" == "ocl" ]; then
    module load pocl/1.5
  fi
  check_bin $RUN_DIR/$BENCHMARK_EXE
  qsub -o BabelStream-large-$CONFIG.out -N babelstream -V $SCRIPT_DIR/run-large.job
elif [ "$ACTION" == "run-large-scale" ]; then
  if [ "$MODEL" == "ocl" ]; then
    module load pocl/1.5
  fi
  check_bin $RUN_DIR/$BENCHMARK_EXE
  qsub -o BabelStream-large-scale-$CONFIG.out -N babelstream -V $SCRIPT_DIR/run-large-scale.job
else
  echo
  echo "Invalid action"
  usage
  exit 1
fi
