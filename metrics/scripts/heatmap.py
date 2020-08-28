#!/usr/bin/python
# Copyright (c) 2020 Performance Portability authors
# SPDX-License-Identifier: MIT

import argparse
import csv
import numpy as np
import matplotlib.pyplot as plt
from mpl_toolkits.axes_grid1 import make_axes_locatable

# Argument parsing
parser = argparse.ArgumentParser()
parser.add_argument("input",  help="CSV input file")
parser.add_argument("output", help="PDF output file")
parser.add_argument("--higher-is-better", help="High numbers are better than low number (e.g. when plotting bandwidth)", action="store_true")
parser.add_argument("--factorize", help="Divide all input results by this number", action="store", type=float, default=1.0)
parser.add_argument("--percent", help="Input is in percent", action="store_true")
parser.add_argument("--mean", help="Plot the mean and standard deviation against each column", action="store_true")
args = parser.parse_args()

# Open the input .csv file
data = csv.DictReader(open(args.input))

# Get the list of headings from first row
headings = data.fieldnames[1:]

# Name of the series, what the rows in the CSV actually are
series_key = data.fieldnames[0]


series = [] # a row in the input file

heatmap = [] # empty, to be populated by reading the input file
labels = [] # labels to display in each heatmap entry

for result in data:
    def get(name):
        str = result[name]
        try:
            return float(str)
        except:
            return str
    def eff(a, b):
        if isinstance(a, float) and isinstance(b, float):
            return float(100.0 * (a / b))
        elif a is '-' or b is '-':
            return float(-100.0)
        else:
            return float(0.0)

    raw = [get(h) for h in headings]

    # Skip over applications without any results
    if not any([isinstance(x, float) for x in raw]):
        continue

    # Divide each raw result by the best result.
    #if result['benchmark'] in ['STREAM','GROMACS']:
    #    best = max(x for x in raw if isinstance(x, float))
    #    efficiencies = [eff(x, best) for x in raw]
    #else:
    #    best = min(x for x in raw if isinstance(x, float))
    #    efficiencies = [eff(best, x) for x in raw]

    series.append(result[series_key])
    heatmap.append([r if isinstance(r, float) else 0.0 for r in raw])


    l = []
    for i in range(len(raw)):
        if not isinstance(raw[i], float):
            l.append('-')
        else:
            if args.percent:
                l.append('%.0f\\%%' % (raw[i]/args.factorize))
            else:
                if raw[i]/args.factorize < 100.0:
                    l.append('%.1f' % (raw[i]/args.factorize))
                else:
                    l.append('%.0f' % (raw[i]/args.factorize))

    labels.append(l)


plt.rc('text', usetex=True)
plt.rc('font', family='serif', serif='Computer Modern Roman')
fig, ax = plt.subplots()
fig.set_size_inches(4, 3)
colors = "summer_r"
colors = "inferno"
colors = "gist_heat"
# Set map so red is best, green is worst
cmap = plt.cm.get_cmap(colors) if args.higher_is_better else plt.cm.get_cmap(colors+"_r")
#cmap.set_under('w')
#plt.pcolor(np.array(heatmap), cmap=cmap, edgecolors='k', vmin=1.0E-6)
x = np.arange(7)
y = np.arange(11)
cmesh = plt.pcolormesh(x, y, np.array(heatmap), cmap=cmap, edgecolors='k', vmin=1.0E-6)
ax.set_yticks(np.arange(len(heatmap)) + 0.5, minor=False)
ax.set_xticks(np.arange(len(heatmap[0])) + 0.5, minor=False)

#ax.set_aspect(0.25, adjustable='box')
#ax.set_yticklabels(series, fontsize='xx-large')
ax.set_yticklabels(series)
for i in range(len(headings)):
  headings[i] = headings[i].replace('_', '\_')
#ax.set_xticklabels(headings, fontsize='xx-large', rotation=45)
ax.set_xticklabels(headings, rotation=45, ha="right", rotation_mode="anchor")
plt.gca().invert_yaxis()

# Add colorbar
#divider = make_axes_locatable(ax)
#cax = divider.append_axes("right", size="5%", pad=0.05)
#plt.colorbar(cmesh, cax=cax)
#plt.colorbar(cmesh, fraction=0.046, pad=0.04)
plt.colorbar(cmesh)

# Add labels
for i in range(len(headings)):
    for j in range(len(series)):
        #plt.text(i + 0.5, j + 0.55, labels[j][i],
        plt.text(i + 0.9, j + 0.5, labels[j][i],
                 ha='right', va='center', color='#b9c5bf', weight='bold')

# Add caption
#if args.higher_is_better:
#    plt.title("Higher is better", fontsize='xx-large')
#else:
#    plt.title("Lower is better", fontsize='xx-large')

# Add mean and standard deviation if required
#if args.mean:
#  heatmap = np.array(heatmap)
#  # Calculate mean and standard deviation for each row
#  means = np.mean(heatmap, axis=1)
#  stdev = np.std(heatmap, axis=1)
#  print(means)
#  print(stdev)
#
#  # Plot on graph as extra column
#  plt.text(len(headings) + 0.5, 0, "Mean",
#                 ha='center', va='center', color='black', weight='bold', size='xx-large')
#  plt.text(len(headings) + 1.5, 0, "Std. Dev.",
#                 ha='center', va='center', color='black', weight='bold', size='xx-large')
#  for i in range(len(series)):
#    plt.text(len(headings) + 0.5, i + 0.5, "%.1f" % means[i],
#                 ha='center', va='center', color='black', weight='bold', size='xx-large')
#    plt.text(len(headings) + 1.5, i + 0.5, "%.1f" % stdev[i],
#                 ha='center', va='center', color='black', weight='bold', size='xx-large')


plt.savefig(args.output, bbox_inches='tight')
