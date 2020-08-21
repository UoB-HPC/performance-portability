#!/bin/bash

DEFAULT_COMPILER=intel-2020
DEFAULT_MODEL=mpi
function usage
{
    echo
    echo "Usage: ./benchmark.sh build|run [MODEL] [COMPILER]"
    echo
    echo "Valid model and compiler options:"
    echo "  mpi | omp"
    echo "    intel-2020"
    echo "    gcc-9.1"
    echo "    aocc-2.1"
    echo
    echo "  kokkos"
    echo "    gcc-9.1"
    echo
    echo "  acc"
    echo "    pgi-20.1"
    echo
    echo "  sycl"
    echo "    hipsycl"
    echo
    echo "The default configuration is '$DEFAULT_COMPILER $DEFAULT_MODEL'."
    echo
}

# Process arguments
if [ $# -lt 1 ]
then
    usage
    exit 1
fi

ACTION="$1"
export MODEL="${2:-$DEFAULT_MODEL}"
COMPILER="${3:-$DEFAULT_COMPILER}"
SCRIPT="$(realpath "$0")"
SCRIPT_DIR="$(realpath "$(dirname "$SCRIPT")")"
source "$SCRIPT_DIR/../common.sh"

export BENCHMARK_EXE=clover_leaf
export CONFIG="rome_${COMPILER}_${MODEL}"
export SRC_DIR="$PWD/CloverLeaf_ref"
export RUN_DIR="$PWD/CloverLeaf-$CONFIG"


# Set up the environment
case "$COMPILER" in
    gcc-9.1)
        module purge
        module load lang/gcc/9.1.0
        module use /home/td8469/software/modulefiles
        module load openmpi/4.0.4-mpi1
        MAKE_OPTS='COMPILER=GNU MPI_COMPILER=mpif90 C_MPI_COMPILER=mpicc'
        MAKE_OPTS=$MAKE_OPTS' FLAGS_GNU="-Ofast -ffast-math -ffp-contract=fast -march=znver2 -funroll-loops"'
        MAKE_OPTS=$MAKE_OPTS' CFLAGS_GNU="-Ofast -ffast-math -ffp-contract=fast -march=znver2 -funroll-loops"'
        ;;
    intel-2020)
        module purge
        module load lang/intel-parallel-studio-xe/2020 
        MAKE_OPTS='COMPILER=INTEL MPI_COMPILER=mpiifort C_MPI_COMPILER=mpiicc OMP_INTEL=-qopenmp'
        MAKE_OPTS=$MAKE_OPTS' FLAGS_INTEL="-O3"'
        MAKE_OPTS=$MAKE_OPTS' CFLAGS_INTEL="-O3 -restrict -fno-alias"'
        ;;
    aocc-2.1)
        module purge
        module use /home/td8469/software/modulefiles
        module load aocc/2.1.0 openmpi/4.0.4-aocc
        export OMPI_CC=clang OMPI_F90=flang
        MAKE_OPTS='COMPILER=GNU MPI_COMPILER=mpif90 C_MPI_COMPILER=mpicc'
        MAKE_OPTS=$MAKE_OPTS' FLAGS_GNU="-Ofast -ffast-math -ffp-contract=fast -march=znver2 -funroll-loops"'
        MAKE_OPTS=$MAKE_OPTS' CFLAGS_GNU="-Ofast -ffast-math -ffp-contract=fast -march=znver2 -funroll-loops"'
        ;;
    pgi-19.10)
        module purge
        module use /home/td8469/software/modulefiles
        module load pgi/19.10
        export PATH=/home/td8469/software/pgi/19.10/linux86-64/19.10/mpi/openmpi-3.1.3/bin:$PATH
        MAKE_OPTS="COMPILER=PGI MPI_COMPILER=mpif90 C_MPI_COMPILER=mpicc"
        ;;
    hipsycl)
        module use /home/td8469/software/modulefiles
        module load hipsycl/master-12-jun-2020
        module load openmpi/4.0.4-mpi1
        ;;
    *)
        echo
        echo "Invalid compiler '$COMPILER'."
        usage
        exit 1
        ;;
esac


case "$MODEL" in
    omp|mpi)
        case "$COMPILER" in
          intel-2020|gcc-9.1|aocc-2.1)
            ;;
          *)
            echo
            echo "Invalid compiler '$COMPILER'."
            usage
            exit 1
            ;;
        esac
        ;;

    kokkos)
        case "$COMPILER" in
          gcc-9.1)
            ;;
          *)
            echo
            echo "Invalid compiler '$COMPILER'."
            usage
            exit 1
            ;;
        esac
        KOKKOS_PATH=$(pwd)/$(fetch_kokkos)
        echo "Using KOKKOS_PATH=${KOKKOS_PATH}"
        MAKE_FILE="Kokkos.make"
        BINARY="kokkos-stream"
        MAKE_OPTS+=" KOKKOS_PATH=${KOKKOS_PATH} ARCH=EPYC DEVICE=OpenMP"
        export SRC_DIR=$PWD/cloverleaf_kokkos
        ;;

    acc)
        case "$COMPILER" in
          pgi-19.10)
            ;;
          *)
            echo
            echo "Invalid compiler '$COMPILER'."
            usage
            exit 1
            ;;
        esac
        MAKE_OPTS=$MAKE_OPTS' FLAGS_PGI="-O3 -Mpreprocess -fast -acc -ta=multicore -tp=zen" CFLAGS_PGI="-O3 -ta=multicore -tp=zen" OMP_PGI=""'
        export SRC_DIR=$PWD/CloverLeaf-OpenACC
        ;;

    sycl)
      
        HIPSYCL_PATH=$(realpath $(dirname $(which syclcc))/..)
        echo "Using HIPSYCL_PATH=${HIPSYCL_PATH}"
        MAKE_OPTS+=" -DHIPSYCL_INSTALL_DIR=${HIPSYCL_PATH} -DSYCL_RUNTIME=HIPSYCL"
      
        BINARY="clover_leaf"
        export SRC_DIR=$PWD/cloverleaf_sycl
        export DEVICE_ARGS="--device 1"
        ;;

    *)
        echo
        echo "Invalid model '$MODEL'."
        usage
        exit 1
        ;;
esac


# Handle actions
if [ "$ACTION" == "build" ]
then
    # Fetch source code
    fetch_src "$MODEL"

    # Perform build
    rm -f $SRC_DIR/$BENCHMARK_EXE $RUN_DIR/$BENCHMARK_EXE

    if [ "$MODEL" == "sycl" ]; then
      cd $SRC_DIR || exit
      rm -rf build
      module load tools/cmake/3.14.2
      module load lang/gcc/9.1.0
      cmake -Bbuild -H. -DCMAKE_BUILD_TYPE=Release $MAKE_OPTS -DCMAKE_C_COMPILER=gcc -DCMAKE_CXX_COMPILER=g++
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

elif [ "$ACTION" == "run" ]
then
    check_bin "$RUN_DIR/$BENCHMARK_EXE"

    qsub \
        -o CloverLeaf-$CONFIG.out \
        -N cloverleaf \
        -V \
        $SCRIPT_DIR/run.job
else
    echo
    echo "Invalid action (use 'build' or 'run')."
    echo
    exit 1
fi
