#!/bin/bash
# shellcheck disable=SC2034 disable=SC2153

set -eu

module load cmake/3.14.5

setup_env() {
  USE_QUEUE=false
  case "$COMPILER" in
    hipcc-2.8)
      # TODO kokkos via hipcc
      exit 1
      ;;
    gcc-10.1)
      module load gcc/10.1.0
      # TODO omp-target via gcc
      exit 1
      ;;
    
    hipsycl-cf71460) # TODO change hipsycl-<hash> to the appropriate one 

      # TODO from p3hpc, doesn't compile 
      module load hipsycl/master-mar-18
      module load gcc/8.3.0

      # TODO replace with the following:
      # module load gcc/10.2.0 boost/1.73.0/gcc-10.2.0 hipsycl/cf71460/gcc-10.2.0
      # module load llvm/10.0 # hipSYCL adds -lomp so we need this on path

      # HIPSYCL_ROCM_LINK_LINE=""
      # local ROCM_TOOLKIT_LIB="/opt/rocm/lib64" 
      
      # # XXX might not even need the -Wl stuff
      # # in theory, this should have been done by syclcc
      # # default-rocm-link-line in <modules>/hipsycl/b13c71f/gcc-<version>/etc/hipSYCL/syclcc.json
      # HIPSYCL_ROCM_LINK_LINE+=" -Wl,-rpath=$ROCM_TOOLKIT_LIB -L$ROCM_TOOLKIT_LIB"       

      # HIPSYCL_ROCM_LINK_LINE+=" $BOOST_ROOT/lib/libboost_context.so"
      # HIPSYCL_ROCM_LINK_LINE+=" $BOOST_ROOT/lib/libboost_fiber.so"
      # export HIPSYCL_ROCM_LINK_LINE


      MAKE_OPTS=" -DSYCL_RUNTIME=HIPSYCL"
      MAKE_OPTS+=" -DNUM_TD_PER_THREAD=16"
      MAKE_OPTS+=" -DCXX_EXTRA_FLAGS=-mtune=native"
      MAKE_OPTS+=" -DHIPSYCL_INSTALL_DIR=$(findhipSYCL)"
      MAKE_OPTS+=" -DHIPSYCL_PLATFORM=rocm -DHIPSYCL_GPU_ARCH=gfx906"
      MAKE_OPTS+=" -DCMAKE_C_COMPILER=gcc -DCMAKE_CXX_COMPILER=g++"
      # MAKE_OPTS+=" -DCXX_EXTRA_FLAGS=--gcc-toolchain=$(findGCC)"
      ;;      
    *)
      echo
      echo "Invalid compiler '$COMPILER'."
      usage
      exit 1
      ;;
  esac
}
export -f setup_env

script="$(realpath "$0")"
SCRIPT_DIR="$(realpath "$(dirname "$script")")"
PLATFORM_DIR="$(realpath "$(dirname "$script")")"
export SCRIPT_DIR PLATFORM_DIR

export COMPILERS="hipcc-2.8 gcc-10.1 hipsycl-cf71460"
export DEFAULT_COMPILER="cce-10.0"
export MODELS="kokkos omp-target sycl"
export DEFAULT_MODEL="kokkos"
export PLATFORM="radeonvii-zoo"

export KOKKOS_BACKEND="HIP"
export KOKKOS_ARCH="Vega906"
export KOKKOS_WGSIZE="2"
# defaults to O3, don't add Ofast here as nvcc chokes
export KOKKOS_EXTRA_FLAGS="-march=native"


bash "$PLATFORM_DIR/../common.sh" "$@"
