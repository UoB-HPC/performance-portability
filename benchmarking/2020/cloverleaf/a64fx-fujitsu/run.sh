#!/bin/bash

cd "$RUN_DIR" || exit 1

cp "$SRC_DIR/InputDecks/clover_bm16.in" clover.in

date

case "$MODEL" in
    mpi)
        OMP_NUM_THREADS=1 mpirun -np 48 "./$BENCHMARK_EXE"
        ;;
    omp|kokkos)
        export OMP_PROC_BIND=true OMP_PLACES=cores OMP_NUM_THREADS=48
        if [[ "$COMPILER" =~ fujitsu- ]]; then
            mpirun -np 1 "./$BENCHMARK_EXE"
        else
            "./$BENCHMARK_EXE"
        fi
        ;;
    *)
        echo "Unknown run configuration for model '$MODEL'"
        exit 2
        ;;
esac

