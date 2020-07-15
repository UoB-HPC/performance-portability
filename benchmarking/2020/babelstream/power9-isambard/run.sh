#!/bin/bash

set -eu
export OMP_PROC_BIND=spread
date >../$1
"./$BENCHMARK_EXE" &>>../$1

