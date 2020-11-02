#!/usr/bin/env python3
# Copyright (c) 2020 Performance Portability authors
# SPDX-License-Identifier: MIT

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt

import argparse
from statistics import mean, harmonic_mean, median
import math
import sys


def geomean(n):
    # geometric_mean was not added to statistics until Python 3.8
    if (sys.version_info.major > 3) or (
            sys.version_info.major == 3 and sys.version_info.minor >= 8):
        return statistics.geometric_mean(n)
    else:
        return np.prod(n)**(1.0 / float(len(n)))


def harmean(n):
    # Python harmonic_mean returns 0 if there is a 0 in the input
    # Return NaN instead to distinguish from pp
    if 0 in n:
        return np.nan
    return harmonic_mean(n)


def pp(n):
    if 0 in n:
        return 0
    return harmonic_mean(n)


# Set up argument parsing
parser = argparse.ArgumentParser(
    description="Produce table of \"average\" efficiencies")
parser.add_argument(
    'input_file',
    help="CSV file containing performance data")
parser.add_argument(
    'output_file',
    help="Output TeX file")
parser.add_argument(
    '--calc-efficiency',
    action="store_true",
    help="Calculate application efficiency")
parser.add_argument(
    '--input-is-throughput',
    action="store_true",
    help="If calculating application efficiency, then treat the data as throughput (higher is better)")
parser.add_argument(
    '--sort',
    action="store_true",
    help="Sort columns according to performance portability")

args = parser.parse_args()


print('Performance portability metrics')
print()
print('Input file: {}'.format(args.input_file))
print()

# Read in the CSV file as a Pandas DataFrame
data = pd.read_csv(
    args.input_file,
    skipinitialspace=True,
    sep=r',\s+',
    delimiter=',',
    na_values='X')

# In the case of trailing whitespace, the X don't get converted.
# This replaces anything starting with an X to a NaN
data = data.replace(r'^X', np.nan, regex=True)

# Make sure the data is all floating point
data[list(data.columns[1:])] = data[list(
    data.columns[1:])].apply(pd.to_numeric)


print(data)

# Save a version where NaN is set to 0
data_nona = data.fillna(float(0.0))

if (args.calc_efficiency):
    print("Calculating application efficiency...")

    # Calculate application efficiency
    if (not args.input_is_throughput):
        minimums = data.min(axis=1, skipna=True)
        for col in list(data.columns[1:]):
            data_nona[col] = 100.0 * minimums[:] / data_nona[col]
        data_nona = data_nona.replace([np.inf, -np.inf, np.nan], 0.0)

    else:
        maximums = data.max(axis=1, skipna=True)
        for col in list(data.columns[1:]):
            data_nona[col] = data_nona[col] / maximums[:] * 100.0
        data_nona = data_nona.replace([np.inf, -np.inf, np.nan], 0.0)

else:
    print("Warning: using input data as efficiencies")

# Display data information
print('Number of data items:')
print(data.count())
print()

print(data_nona)

# Compute "averages" for each implementation after discarding non-numeric data
data_nona = data_nona.drop('Device', axis=1)
averages = {"Minimum": min,
            "Arithmetic Mean": mean,
            "Geometric Mean": geomean,
            "Harmonic Mean": harmean,
            "Median": median,
            "Performance Portability": pp}
results = pd.DataFrame()
for (name, f) in averages.items():
    avg = data_nona.apply(f, raw=True).copy()
    avg.name = name
    results = results.append(avg, ignore_index=False)

# Sort columns according to their PP value
# sort_index is not supported by old Pandas
if args.sort:
    order = sorted([col for col in results.columns],
                   key=lambda col: results[col]['Performance Portability'])
    results = results.reindex(order, axis=1)

print()
print(results)

# Write table to LaTeX file
results.to_latex(args.output_file, float_format="%.2f")

print(80 * '-')
print()
print()
