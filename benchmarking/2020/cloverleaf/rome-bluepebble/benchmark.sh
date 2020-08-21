#!/bin/bash

DEFAULT_COMPILER=intel-2020
DEFAULT_MODEL=mpi
function usage
{
    echo
    echo "Usage: ./benchmark.sh build|run [MODEL] [COMPILER]"
    echo
    echo "Valid compilers:"
    echo "  pgi-20.1"
    echo
    echo "Valid model and compiler options:"
    echo "  mpi | omp"
    echo "    intel-2020"
    echo "    gcc-9.1"
    echo "    aocc-2.1"
    echo "  omp"
    echo "  kokkos"
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
    pgi-20.1)
        module swap PrgEnv-{cray,pgi}
        module swap pgi pgi/20.1.1
        MAKE_OPTS='COMPILER=PGI C_MPI_COMPILER=cc MPI_COMPILER=ftn'
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
        module use /lus/snx11029/p02100/modules/modulefiles
        module load kokkos/2.8.00/intel/skylake
        MAKE_OPTS='CXX=CC'
        export SRC_DIR=$PWD/cloverleaf_kokkos
        ;;

    acc)
        MAKE_OPTS=$MAKE_OPTS' FLAGS_PGI="-O3 -Mpreprocess -fast -acc -ta=multicore -tp=skylake" CFLAGS_PGI="-O3 -ta=multicore -tp=skylake" OMP_PGI=""'
        export SRC_DIR=$PWD/CloverLeaf-OpenACC
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
    if ! eval make -C $SRC_DIR -B $MAKE_OPTS
    then
        echo
        echo "Build failed."
        echo
        exit 1
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
