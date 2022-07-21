#!/bin/bash

set -eu

if ! grep -q bristol/modules-a64fx/ <<<"$MODULEPATH"; then
  module use /lustre/projects/bristol/modules-a64fx/modulefiles
fi
if ! grep -q lustre/software/aarch64/ <<<"$MODULEPATH"; then
  module use /lustre/software/aarch64/modulefiles
fi

DEFAULT_COMPILER=fujitsu-1.2.26
DEFAULT_MODEL=omp
function usage
{
    echo
    echo "Usage: ./benchmark.sh build|run [COMPILER] [MODEL]"
    echo
    echo "Valid compilers:"
    echo "  fujitsu-1.2.26"
    echo "  gcc-8.3"
    echo "  armclang-20.1"
    echo "  hipsycl-200902-gcc"
    echo "  julia-1.6.2"
    echo
    echo "Valid models:"
    echo "  omp"
    echo "  kokkos"
    echo "  sycl"
    echo "  julia-ka"
    echo "  julia-threaded"
    echo
    echo "The default configuration is '$DEFAULT_COMPILER'."
    echo "The default programming model is '$DEFAULT_MODEL'."
    echo
}

# Process arguments
if [ $# -lt 1 ]
then
    usage
    exit 1
fi

ACTION=$1
COMPILER=${2:-$DEFAULT_COMPILER}
export MODEL=${3:-$DEFAULT_MODEL}
SCRIPT=$(realpath $0)
SCRIPT_DIR=$(realpath $(dirname $SCRIPT))
source ${SCRIPT_DIR}/../common.sh

export CONFIG="a64fx"_"$COMPILER"_"$MODEL"
export BENCHMARK_EXE=BabelStream-$CONFIG
export SRC_DIR=$PWD/BabelStream
export RUN_DIR=$PWD/BabelStream-$CONFIG


case "$COMPILER" in
      julia-1.6.2)
        module load julia/1.6.2
        ;;
    fujitsu-4.3.1)
        module load fujitsu-compiler/4.3.1
        MAKE_OPTS='COMPILER=FUJITSU COMPILER_FUJITSU=FCC FLAGS_FUJITSU="-Kfast,zfill,openmp,cmodel=large,restp -std=c++11" OMP_FUJITSU_CPU="-fopenmp"'
        ;;
    gcc-11.1.0)
        module load gcc/11.1.0
        MAKE_OPTS='COMPILER=GNU'
        ;;
    llvm-11.0)
      module load llvm/11.0
      MAKE_OPTS='COMPILER=CLANG TARGET=CPU OMP_CLANG_CPU=-fopenmp EXTRA_FLAGS=""'
        ;;    
    armclang-21.0)
        # export ALLINEA_LICENSE_DIR=/software/licence/arm-forge
        # export ARM_LICENSE_DIR=/software/licence/arm-forge
        # module use /snx11273/home/br-wlin/arm-compiler-for-linux_21.0_RHEL-8_aarch64/install/modulefiles
        # module load arm21/21.0
        # # module load arm/20.3
        module load tools/arm-compiler-a64fx/21.0
        # -fno-signed-zeros -fno-trapping-math -fassociative-math
        MAKE_OPTS='COMPILER=ARMCLANG CXXFLAGS="-fopenmp -O3 -mcpu=a64fx "'
        ;;
    hipsycl-200902-gcc)
      module load hipsycl/200902-gcc
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
export COMPILER="$COMPILER"
# Handle actions
if [ "$ACTION" == "build" ]
then

  # Fetch source code
  fetch_src

  # Select Makefile to use, and model specific information
  case "$MODEL" in
    julia-*)
      # nothing to do
    ;;
    omp)
      if [ "$COMPILER" == "fujitsu-1.2.26" ]; then
        WORK_DIR=$PWD
        cd $SRC_DIR
        patch < $SCRIPT_DIR/restrict-pointers.patch
        cd $WORK_DIR
      fi
      MAKE_FILE="OpenMP.make"
      BINARY="omp-stream"
      MAKE_OPTS+=" TARGET=CPU"
      ;;
    kokkos)
      KOKKOS_PATH=$(pwd)/$(fetch_kokkos)
      echo "Using KOKKOS_PATH=${KOKKOS_PATH}"
      MAKE_FILE="Kokkos.make"
      BINARY="kokkos-stream"
      MAKE_OPTS+=" KOKKOS_PATH=${KOKKOS_PATH} ARCH=A64FX DEVICE=OpenMP"
      ;;
    acc)
      MAKE_FILE="OpenACC.make"
      BINARY="acc-stream"
      MAKE_OPTS+=' TARGET=SKL'
      if [ "$COMPILER" != "pgi-20.1" ]
      then
        echo
        echo " Must use PGI with OpenACC"
        echo
        exit 1
      fi
    ;;
    ocl)
      module use /home/users/p02639/bin/modulefiles
      module load intel-opencl-experimental
      module load khronos/opencl-headers
      MAKE_FILE="OpenCL.make"
      BINARY="ocl-stream"
      #export LD_PRELOAD=/lus/scratch/p02555/modules/intel-opencl/lib/libintelocl.so
      #export LD_PRELOAD=/lus/scratch/p02100/l_opencl_p_18.1.0.013/opt/intel/opencl_compilers_and_libraries_18.1.0.013/linux/compiler/lib/intel64_lin/libintelocl.so
      ;;
    sycl)
      HIPSYCL_PATH=$(realpath $(dirname $(which syclcc))/..)
      echo "Using HIPSYCL_PATH=${HIPSYCL_PATH}"
      MAKE_OPTS+=" SYCL_SDK_DIR=${HIPSYCL_PATH}"
      MAKE_FILE="SYCL.make"
      BINARY="sycl-stream"
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
