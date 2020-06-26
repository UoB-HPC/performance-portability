#!/usr/local/bin/python3

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt

import argparse

# Set up argument parsing
parser = argparse.ArgumentParser(description="Produce histogram of efficiency")
parser.add_argument('input_file', help="CSV file containing performance data")
parser.add_argument('output_file', help="Output PDF file")
parser.add_argument('--calc-efficiency', action="store_true", help="Calculate application efficiency")
parser.add_argument('--input-is-throughput', action="store_true", help="If calculating application efficiency, then treat the data as throughput (higher is better)")

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

# Group bar chart
# First manually bin the data
# First group should be zeros, then (0.0-10.0), [10.0-20.0), etc
bins = np.arange(0,110,10, dtype=np.float)
bins[0] = np.finfo(float).eps
bins = np.append(np.zeros(1), bins)
bar_data = {}
for col in list(data_nona.columns[1:]):
  bar_data[col] = pd.value_counts(data_nona[col], sort=False, bins=bins) / data_nona[col].count() * 100.0
pd.DataFrame(bar_data).plot.bar()
plt.ylabel('Frequency in %')
plt.xlabel('% peak performance')
plt.ylim([0.0,100.0])
plt.grid(axis='y')
# Rename the first bin
locs, labels = plt.xticks()
labels[0] = "Did not run"
labels[1] = "(0.0, 10.0]"
plt.xticks(locs, labels)
plt.savefig(args.output_file, bbox_inches='tight')
plt.close()

print(80*'-')
print()
print()

