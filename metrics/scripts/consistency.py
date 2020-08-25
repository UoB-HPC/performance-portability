#!/usr/bin/env python3
# Copyright (c) 2020 Performance Portability authors
# SPDX-License-Identifier: MIT

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt

import argparse
from statistics import harmonic_mean, median, stdev, variance
import math
import sys

# geometric_mean was not added to statistics until Python 3.8
def geomean(n):
  if (sys.version_info.major > 3) or (sys.version_info.major == 3 and sys.version_info.minor >= 8):
    return statistics.geometric_mean(n)
  else:
    return np.prod(n)**(1.0/float(len(n)))

# Python harmonic_mean returns 0 if there is a 0 in the input
# Return NaN instead to distinguish from pp
def harmean(n):
  if 0 in n:
    return np.nan
  return harmonic_mean(n)

# Harmonic standard deviation as calculated in the following papers:
# C. Bertoni et al., "Performance Portability Evaluation of OpenCL Benchmarks across Intel and NVIDIA Platforms", IPDPSW 2020
# M. Martinez and M. Bartholomew, "What does it "Mean"? A Review of Interpreting and Calculating Different Types of Means and Standard Deviations", Pharmaceutics, vol. 9, no. 2, pp. 14, 2017
def harstdev_martinez(n):
  if 0 in n:
    return np.nan
  h = harmean(n)
  return h**2 * np.sqrt(sum([(1.0/x - 1.0/h)**2 / float(len(n)-1) for x in n]))

# Harmonic standard deviation as calculated in:
# F.C. Lam et al., "Estimation of Variance for Harmonic Mean Half-Lives", Journal of Pharmaceutical Sciences, vol. 74, no. 2, pp. 229-231, 1985
def hbar(x, i):
    s = sum((1.0/v) for (c, v) in enumerate(x) if c != i)
    return (len(x)-1)/s

def harvar(x):
    hbararr = [hbar(x,i) for i in range(len(x))]
    hbarbar = sum(hbararr)/len(x)
    return (len(x)-1) * sum( (hbararr - hbarbar)**2.0)

def harstdev_lam(n):
  if 0 in n:
    return np.nan
  return harvar(n)**0.5

# median absolute deviation
def mad(n):
  m = median(n)
  return median([abs(x - m) for x in n])

# Distance between min and max values
def data_range(n):
  return max(n) - min(n)

def pp(n):
  if 0 in n:
    return 0
  return harmonic_mean(n)

# Set up argument parsing
parser = argparse.ArgumentParser(description="Produce table of \"average\" efficiencies")
parser.add_argument('input_file', help="CSV file containing performance data")
parser.add_argument('output_file', help="Output TeX file")
parser.add_argument('--calc-efficiency', action="store_true", help="Calculate application efficiency")
parser.add_argument('--input-is-throughput', action="store_true", help="If calculating application efficiency, then treat the data as throughput (higher is better)")
parser.add_argument('--sort', action="store_true", help="Sort columns according to performance portability")

args = parser.parse_args()


print('Performance portability metrics')
print()
print('Input file: {}'.format(args.input_file))
print()

# Read in the CSV file as a Pandas DataFrame
data = pd.read_csv(args.input_file, skipinitialspace=True, sep=',\s+', delimiter=',', na_values='X')

# In the case of trailing whitespace, the X don't get converted.
# This replaces anything starting with an X to a NaN
data = data.replace(r'^X', np.nan, regex=True)

# Make sure the data is all floating point
data[list(data.columns[1:])] = data[list(data.columns[1:])].apply(pd.to_numeric)


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

# Compute "consistency" measures for each implementation after discarding
# non-numeric data
data_nona = data_nona.drop('Device', axis=1)
measures = { "Standard Deviation" : stdev,
             "Harmonic Standard Deviation (Martinez)" : harstdev_martinez,
             "Harmonic Standard Deviation (Lam)" : harstdev_lam,
             "Median Absolute Deviation" : mad,
             "Range" : data_range }
results = pd.DataFrame()
for (name, f) in measures.items():
  measure = data_nona.apply(f, raw=True).copy()
  measure.name = name
  results = results.append(measure, ignore_index=False)

# Sort columns according to their PP value
# sort_index is not supported by old Pandas
if args.sort:
    measure = data_nona.apply(pp, raw=True).copy()
    order = sorted([col for col in results.columns], key=lambda col:measure[col])
    results = results.reindex(order, axis=1)

print()
print(results)

# Write table to LaTeX file
results.to_latex(args.output_file, float_format="%.2f")

print(80*'-')
print()
print()

