#!/bin/bash

set -eu
export OMP_PROC_BIND=spread
date >../$1
"./$BENCHMARK_EXE" --arraysize $((2 ** 29)) &>>../$1
