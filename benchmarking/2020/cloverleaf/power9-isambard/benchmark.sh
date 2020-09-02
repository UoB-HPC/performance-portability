#!/bin/bash

set -e

DEFAULT_COMPILER=pgi-18
DEFAULT_MODEL=omp
function usage
{
    echo
    echo "Usage: ./benchmark.sh build|run [COMPILER] [MODEL]"
    echo
    echo "Valid compilers:"
    echo "  gcc-8.1"
    echo "  pgi-19.10"
    echo "  xl-16"
    echo
    echo "Valid models:"
    echo "  mpi"
    echo "  omp"
    echo "  acc"
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

ACTION=$1
export COMPILER=${2:-$DEFAULT_COMPILER}
export MODEL=${3:-$DEFAULT_MODEL}
SCRIPT=`realpath $0`
SCRIPT_DIR=`realpath $(dirname $SCRIPT)`

source ${SCRIPT_DIR}/../common.sh

export CONFIG="power9"_"$COMPILER"_"$MODEL"
export SRC_DIR=$PWD/CloverLeaf_ref
export RUN_DIR=$PWD/CloverLeaf-$CONFIG
export BENCHMARK_EXE=CloverLeaf-$CONFIG


# Set up the environment
if ! grep -q "/lustre/projects/bristol/modules-power/modulefiles" <<<"$MODULEPATH"; then
    module use /lustre/projects/bristol/modules-power/modulefiles
fi
module purge
case "$COMPILER" in
    gcc-8.1)
        module load gcc/8.1.0 openmpi/3.0.2/gcc8
        MAKE_OPTS='COMPILER=GNU'
        MAKE_OPTS=$MAKE_OPTS' FLAGS_GNU="-Ofast -ffast-math -ffp-contract=fast -mcpu=power9 -funroll-loops"'
        MAKE_OPTS=$MAKE_OPTS' CFLAGS_GNU="-Ofast -ffast-math -ffp-contract=fast -mcpu=power9 -funroll-loops"'
        BINARY="clover_leaf"
        ;;
    pgi-19.10)
        module load pgi/compiler/19.10 pgi/openmpi/3.1.3
        MAKE_OPTS='COMPILER=PGI'
        MAKE_OPTS=$MAKE_OPTS' FLAGS_PGI="-fast"'
        MAKE_OPTS=$MAKE_OPTS' CFLAGS_PGI="-fast"'
        BINARY="clover_leaf"
        ;;
    xl-16)
      MAKE_OPTS='COMPILER=XL FLAGS_XL="-O5 -qipa=partition=large -g -qfullpath -Q -qsigtrap -qextname=flush:ideal_gas_kernel_c:viscosity_kernel_c:pdv_kernel_c:revert_kernel_c:accelerate_kernel_c:flux_calc_kernel_c:advec_cell_kernel_c:advec_mom_kernel_c:reset_field_kernel_c:timer_c:unpack_top_bottom_buffers_c:pack_top_bottom_buffers_c:unpack_left_right_buffers_c:pack_left_right_buffers_c:field_summary_kernel_c:update_halo_kernel_c:generate_chunk_kernel_c:initialise_chunk_kernel_c:calc_dt_kernel_c:clover_unpack_message_bottom_c:clover_pack_message_bottom_c:clover_unpack_message_top_c:clover_pack_message_top_c:clover_unpack_message_right_c:clover_pack_message_right_c:clover_unpack_message_left_c:clover_pack_message_left_c -qlistopt -qattr=full -qlist -qreport -qxref=full -qsource -qsuppress=1506-224:1500-036FLAGS_"'
      BINARY="clover_leaf"
      ;;
    *)
        echo
        echo "Invalid compiler '$COMPILER'."
        usage
        exit 1
        ;;
esac

case "$MODEL" in
  acc)
     export SRC_DIR="$PWD/CloverLeaf-OpenACC"
     MAKE_OPTS='COMPILER=PGI FLAGS_PGI="-O3 -Mpreprocess -fast -acc -ta=multicore -tp=pwr9" CFLAGS_PGI="-O3 -ta=multicore -tp=pwr9" OMP_PGI=""'
     ;;
  kokkos)
    export SRC_DIR="$PWD/cloverleaf_kokkos"
    KOKKOS_PATH=$(pwd)/$(fetch_kokkos)
    echo "Using KOKKOS_PATH=${KOKKOS_PATH}"
    MAKE_OPTS="COMPILER=GNU"
    MAKE_OPTS+=" KOKKOS_PATH=${KOKKOS_PATH} ARCH=POWER9 DEVICE=OpenMP"
    ;;
esac


# Handle actions
if [ "$ACTION" == "build" ]
then
  # Fetch source code
  fetch_src "$MODEL"

  # Perform build
  rm -f $RUN_DIR/$BENCHMARK_EXE

  build_bin "$MODEL" "$MAKE_OPTS" "$SRC_DIR" "$BINARY" "$RUN_DIR" "$BENCHMARK_EXE"

elif [ "$ACTION" == "run" ]
then
    check_bin $RUN_DIR/$BENCHMARK_EXE
    cd $RUN_DIR || exit
    bash "$SCRIPT_DIR/run.sh"
else
    echo
    echo "Invalid action (use 'build' or 'run')."
    echo
    exit 1
fi
