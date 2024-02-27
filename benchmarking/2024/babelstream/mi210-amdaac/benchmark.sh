#!/bin/bash

set -eu

SCRIPT_DIR=$(realpath "$(dirname "$(realpath "$0")")")
source "${SCRIPT_DIR}/../../common.sh"
source "${SCRIPT_DIR}/../fetch_src.sh"

handle_cmd "${1}" "${2}" "${3}" "babelstream" "mi210" "xnack_${HSA_XNACK:-}"

export USE_MAKE=false

append_opts "-DCMAKE_VERBOSE_MAKEFILE=ON"

case "$COMPILER" in
rocm-5.7.1)
  export PATH="/opt/rocm-5.7.1/bin:${PATH:-}"
  export ROCM_PATH="/opt/rocm-5.7.1"
  ;;
*) unknown_compiler ;;
esac

fetch_src

case "$MODEL" in
 
hip)
  append_opts "-DMODEL=hip"
  append_opts "-DCMAKE_C_COMPILER=gcc"
  append_opts "-DCMAKE_CXX_COMPILER=hipcc" # auto detected
  append_opts "-DCXX_EXTRA_FLAGS=--offload-arch=gfx90a"
  BENCHMARK_EXE="hip-stream"
  ;;
*) unknown_model ;;
esac

handle_exec
