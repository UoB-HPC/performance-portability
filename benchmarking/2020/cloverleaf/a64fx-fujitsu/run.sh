#!/bin/bash

cd "$RUN_DIR" || exit 1

cp "$SRC_DIR/InputDecks/clover_bm16.in" clover.in

date

case "$MODEL" in
    mpi)
        OMP_NUM_THREADS=1 mpirun -np 48 "./$BENCHMARK_EXE"
        ;;
    omp)
        if [[ "$COMPILER" =~ fujitsu- ]]; then
            OMP_NUM_THREADS=48 mpirun -np 1 "./$BENCHMARK_EXE"
        else
            OMP_NUM_THREADS=48 "./$BENCHMARK_EXE"
        fi
        ;;
    *)
        echo "Unknown run configuration for model '$MODEL'"
        exit 2
        ;;
esac

