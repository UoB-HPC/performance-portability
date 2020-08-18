#!/bin/bash

set -eu
export OMP_PROC_BIND=spread
date >../$1
cp $SRC_DIR/InputDecks/clover_bm16.in clover.in

case "$MODEL" in

sycl)
  mpirun -np 1 "./$BENCHMARK_EXE" --file clover.in --device 1 &>>../$1
  ;;
opencl)
  # Make sure OCL_SRC_PREFIX is set so the kernel source files can be found
  export OCL_SRC_PREFIX=../CloverLeaf
  "./$BENCHMARK_EXE" &>>../$1
  ;;

*)
  "./$BENCHMARK_EXE" &>>../$1
  ;;
esac

