#!/bin/bash

set -eu

call_dir=$PWD

cd "$RUN_DIR"

cp "$SRC_DIR/InputDecks/clover_bm16.in" "$RUN_DIR/clover.in"
[ "$MODEL" = omp-target ] && sed -i '/test_problem 5/a use_c_kernels' "$RUN_DIR/clover.in"

export OMP_NUM_THREADS=1
date
if [ "$MODEL" == "acc" ]
then
  mpirun -np 1 "./$BENCHMARK_EXE"
else
  "./$BENCHMARK_EXE"
fi

cat clover.out > $call_dir/CloverLeaf-"$CONFIG".out
