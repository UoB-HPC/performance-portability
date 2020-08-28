#!/bin/bash
#PBS -q amd
#PBS -l select=1:ncpus=128:mem=256gb
#PBS -l place=excl
#PBS -l walltime=00:30:00
#PBS -joe

cd $RUN_DIR

cp $SRC_DIR/InputDecks/clover_bm16.in clover.in

case "$MODEL" in
    mpi)
        export OMP_NUM_THREADS=1
        I_MPI_DEBUG=4 mpirun -np 128 ./$BENCHMARK_EXE
        ;;
    omp)
        export OMP_NUM_THREADS=128 OMP_PLACES=cores OMP_PROC_BIND=true KMP_AFFINITY=verbose
        ./$BENCHMARK_EXE
        ;;
    acc)
        export ACC_NUM_CORES=128
        taskset -c 0-127 mpirun -np 1 --bind-to none ./$BENCHMARK_EXE
        ;;
    kokkos)
        export OMP_NUM_THREADS=128 OMP_PLACES=cores OMP_PROC_BIND=true KMP_AFFINITY=verbose
        ./$BENCHMARK_EXE
        ;;
    sycl)
        export OMP_NUM_THREADS=128 OMP_PLACES=cores OMP_PROC_BIND=true KMP_AFFINITY=verbose
        ./$BENCHMARK_EXE
        ;;
      
    *)
        echo "Unknown run configuration for model '$MODEL'"
        exit 1
        ;;
esac

