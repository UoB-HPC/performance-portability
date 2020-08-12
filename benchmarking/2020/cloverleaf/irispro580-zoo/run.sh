#!/bin/bash

set -eu
export OMP_PROC_BIND=spread
date >../$1
cp $SRC_DIR/InputDecks/clover_bm16.in clover.in

"./$BENCHMARK_EXE" --file clover.in $DEVICE_ARGS &>>../$1

