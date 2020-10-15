#!/bin/bash

cd "$RUN_DIR" || exit 1

cp "$SRC_DIR/InputDecks/clover_bm16.in" clover.in

date

case "$MODEL" in
    mpi)
        OMP_NUM_THREADS=1 mpirun -np 64 "./$BENCHMARK_EXE"
        ;;
    omp|kokkos)
        export OMP_PROC_BIND=spread OMP_PLACES=cores OMP_NUM_THREADS=64
        mpirun -np 1 --bind-to none "./$BENCHMARK_EXE"
        ;;
    sycl)
        OMP_NUM_THREADS=64 mpirun -np 1 "./$BENCHMARK_EXE"
        ;;
    *)
        echo "Unknown run configuration for model '$MODEL'"
        exit 2
        ;;
esac

