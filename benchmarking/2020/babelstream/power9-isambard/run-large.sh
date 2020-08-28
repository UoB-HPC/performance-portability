#!/bin/bash

set -eu
export OMP_PROC_BIND=spread
export OMP_NUM_THREADS=40
export OMP_PLACES=cores
date >../$1
"./$BENCHMARK_EXE" --arraysize $((2 ** 29)) &>>../$1
