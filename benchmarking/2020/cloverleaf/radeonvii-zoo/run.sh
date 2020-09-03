#!/bin/bash

set -eu
export OMP_PROC_BIND=spread
date >../$1

cd "$RUN_DIR"

if [ "$MODEL" != "ocl" ]; then
  cp "$SRC_DIR/InputDecks/clover_bm16.in" "$RUN_DIR/clover.in"
else
  cp "$SRC_DIR/clover_bm16.in" "$RUN_DIR/clover.in"
  cp "$SRC_DIR"/*.cl "$RUN_DIR"
  cp "$SRC_DIR"/ocl_knls.h "$RUN_DIR"
fi

case "$MODEL" in

sycl)
  mpirun -np 1 "./$BENCHMARK_EXE" --file clover.in --device 0 &>>../$1
  ;;
*)
  "./$BENCHMARK_EXE" &>>../$1
  ;;
esac

cat clover.out > $call_dir/CloverLeaf-"$CONFIG".out
