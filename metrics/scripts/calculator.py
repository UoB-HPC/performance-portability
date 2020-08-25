#!/usr/bin/env python3
# Copyright (c) 2020 Performance Portability authors
# SPDX-License-Identifier: MIT

import csv
from dataclasses import dataclass
from collections import defaultdict
from statistics import mean, stdev, variance, harmonic_mean, median
import numpy as np
from scipy.stats import median_absolute_deviation
import math

@dataclass
class Platform:
    sockets: int
    cores: int
    clock: float
    flops: float
    bw: float
    balance: float

# Not in statistics package for Python 3.7
def geometric_mean(n):
    return np.prod(n)**(1.0/float(len(n)))

# https://en.wikipedia.org/wiki/Geometric_standard_deviation
def geometric_stdev(n):
    g = geometric_mean(n)
    if g == 0:
        return 0
    return math.exp(math.sqrt(np.sum([math.log(x/g)**2 for x in n])/float(len(n))))

# NB: Python harmonic_mean already returns 0 for this case
def pp(n):
    if 0 in n:
        return 0
    return harmonic_mean(n)

def pp_median(n):
    if 0 in n:
        return 0
    return median(n)

def compute(platforms, languages, f):
    print("{}", f)
    # Iterate over subsets of platforms, removing one each time
    # For consistency of plotting across metrics, use order from Deakin's paper
    # TODO: Find a better way to do this
    remove_order = ["", "Radeon VII", "NEC Aurora", "Ampere", "ThunderX2", "Naples", "Power 9", "K20", "KNL", "Skylake"]
    subset = list(platforms)
    for to_remove in remove_order:
        if to_remove in subset:
            subset.remove(to_remove)
        metrics = []
        for l in languages:
            lr = []
            for arch in subset:
                lr.append(results[arch][l])
            metric = f(lr)
            metrics.append(str(metric))
        print("{}, {}".format(len(subset), ", ".join(metrics)))
    print("")

if __name__ ==  "__main__":

    # Read list of platforms from CSV
    platforms = {}
    with open("spec.csv", newline="") as f:
        reader = csv.reader(f, delimiter=",")
        next(reader) # Skip column headers
        for row in reader:
            arch, sockets, cores, clock, flops, bw, balance = row
            platforms[arch] = Platform(int(sockets), int(cores), float(clock), float(flops), float(bw), float(balance))

    # Read BabelStream results from CSV
    results = defaultdict(dict)
    with open("babelstream.csv", newline="") as f:
        reader = csv.reader(f, delimiter =",")
        next(reader) # Skip column headers
        for row in reader:
            arch, openmp, kokkos, cuda, openacc, opencl = row
            results[arch]["openmp"] = float(openmp)
            results[arch]["kokkos"] = float(kokkos)
            results[arch]["cuda"] = float(cuda)
            results[arch]["openacc"] = float(openacc)
            results[arch]["opencl"] = float(opencl)

    # Convert results to architectural efficiencies
    for (arch, result) in results.items():
        peak = platforms[arch].bw
        for (language, perf) in result.items():
            results[arch][language] = ((perf / 1024) / peak) * 100

    # Compute results for each metric of interest
    platforms = list(results.keys())
    languages = list(results[platforms[0]].keys())
    compute(platforms, languages, min)
    compute(platforms, languages, mean)
    compute(platforms, languages, stdev)
    compute(platforms, languages, variance)
    compute(platforms, languages, geometric_mean)
    compute(platforms, languages, geometric_stdev)
    compute(platforms, languages, harmonic_mean)
    compute(platforms, languages, pp)
    compute(platforms, languages, median)
    compute(platforms, languages, median_absolute_deviation)
    compute(platforms, languages, pp_median)
