#!/usr/bin/env python3.7
# Copyright (c) 2020 Performance Portability authors
# SPDX-License-Identifier: MIT

from matplotlib import pylab as plt
from scipy.special import erf
import matplotlib.patches as mpatches
import matplotlib.gridspec as gridspec
from scipy.integrate import simps
import numpy as np
from pathlib import Path

import pandas


def count_zeros(col):
    """Count zeros in column. Helper function to work around pandas weirdness."""
    try:
        return col.value_counts()[0.0]
    except KeyError:
        return 0


def app_effs(filename,
             raw_effs=False,
             raw_effs_scaling=1 / 100.0,
             throughput=False):
    """Load a csv file. Assumes comma separation, and that first column is list of platforms.
    Can interpret values as raw efficiencies, which are scaled from percentages by default.
    Otherwise, computes application efficiencies, possibly intepreting as throughtput.
    Sorts dataframe columns by harmonic mean of efficiencies (major) and by # of unsupported platforms (minor)."""

    df = pandas.read_csv(filename,
                         sep=r"\s*[,]\s*",
                         na_values=[r'x', r'X'],
                         skipinitialspace=True,
                         engine='python')
    if not raw_effs:
        if throughput:
            df[df.columns[1:]] = df[df.columns[1:]].apply(
                lambda r: r / r.max(), axis=1)
        else:
            df[df.columns[1:]] = df[df.columns[1:]].apply(
                lambda r: r.min() / r, axis=1)
    else:
        df[df.columns[1:]] = df[df.columns[1:]].applymap(
            lambda x: x * raw_effs_scaling)
    df = df.fillna(0)
    harmean_vals = df[df.columns[1:]].apply(harmean, axis=0)
    zeros = df[df.columns[1:]].apply(count_zeros, axis=0)
    vals = pandas.DataFrame([harmean_vals, zeros]).sort_values(
        by=0, axis=1).sort_values(by=1, axis=1, ascending=False)
    df = df[df.columns.tolist()[:1] + vals.columns.tolist()]
    return df


def harmean(vals):
    """Compute the harmonic mean of list-like vals. Special case for presence of 0: return 0."""
    try:
        s = sum((1.0 / x for x in vals))
    except ZeroDivisionError:
        return 0.0
    return len(vals) / s


def gaussian(x):
    """Computes unit Gaussian."""
    return 1.0 / np.sqrt(2.0 * np.pi) * np.exp(-0.5 * x**2.0)


def gaussian_cdf(x):
    """Cumulative distribution function of Gaussian."""
    return 0.5 * (1.0 + erf(x * 2**-0.5))


def gaussian_scaling(a, b):
    """Factor needed to scale a unit Gaussian centered at 0 that is truncated into [a,b] back to unity."""
    return -2.0 / (erf(a * 2**-0.5) + erf(-b * 2**-0.5))


class gaussian_family:
    """Describes the functions needed to perform kernel density estimation with Gaussians."""

    def __init__(self):
        """Set Gaussian functions."""
        self.kernel_func = gaussian
        self.scaling_func = gaussian_scaling
        self.cdf_func = gaussian_cdf


def bw_estimate(samples):
    """Computes Abraham's bandwidth heuristic."""
    sigma = np.std(samples)
    cand = ((4 * sigma**5.0) / (3.0 * len(samples)))**(1.0 / 5.0)
    if cand < 1e-7:
        return 1.0
    return cand


class akde:
    """Implements iterative 1D Adapative Kernel Density Estimation, keeping state between stages."""

    def __init__(self, x, samples, bw_fac):
        """reconstruct on grid x, samples is list-like of samples from unknown distribution, bw_fac is scaling factor for reconstruction bandwidth."""
        self.clip = True
        self.kernel_family = gaussian_family()
        self.bw_fac = bw_fac
        self.x = x
        self.samples = samples
        self.last_pdf = None
        self.bw0 = bw_estimate(samples)

    def bw_estimate(self, lx):
        """Choose reconstruction bandwidth to use a point lx. Use constant, initial input if no steps have been taken; otherwise use density estimation from last iterate."""
        if self.last_pdf is None:
            return self.bw0

        return self.bw_fac * (self.density_estimate(lx)**-0.5)

    def density_estimate(self, lx):
        """Estimate density at point lx based on last iterate."""
        assert self.last_pdf is not None

        loc = np.searchsorted(self.x, lx)
        if loc >= len(self.last_pdf):
            return self.last_pdf[-1]
        else:
            return self.last_pdf[loc]

    def pdf(self):
        """Compute a single step of adaptive density estimation using establish parameters. Return PDF and area estimate."""
        scaling_func = self.kernel_family.scaling_func
        kernel_func = self.kernel_family.kernel_func
        pdf = np.zeros(len(self.x))
        for s in self.samples:
            loc_h = self.bw_estimate(s)
            if self.clip:
                assert s >= self.x[0] and s <= self.x[-1]
                scaling = scaling_func((self.x[0] - s) / loc_h, (self.x[-1] - s) / loc_h)
            else:
                scaling = 1.0
            pdf += 1.0 / loc_h * scaling * kernel_func((self.x - s) / loc_h)
        pdf = pdf / len(self.samples)
        self.last_pdf = pdf
        area = simps(pdf, self.x)
        if self.clip and np.fabs(area - 1.0) > 1e-3:
            print(f"Warning: area under PDF is {area}; it should be very close to 1.0. This is likely sampling error.")
        return pdf, area

    def pdf_series(self, num):
        """Compute num iterations of the kernel density estimation process, storing each intermediate."""
        self.last_pdf = None
        res = []
        for i in range(num):
            pdf, area = self.pdf()
            res.append(pdf)
        return res

    def pdf_refine(self, num):
        """Compute num iterations of the kernel density estimation process, storing only the final one."""
        self.last_pdf = None
        for i in range(num):
            pdf, area = self.pdf()
        return pdf


def pp_cdf_raw_effs(theapp):
    """Returns sorted subsequences and harmonic means of same."""
    valid_effs = [x for x in theapp if x[1] > 0 and x[1] != float("inf")]
    sorted_effs = sorted(valid_effs, key=lambda x: x[1])
    res = []
    for i in range(len(sorted_effs)):
        res.append((sorted_effs[i][1], harmean([x[1] for x in sorted_effs[i:]]), sorted_effs[i][0]))
    return res


def plot_pdf(ax, app_eff_df, handles, plat_colors=None, symlog=True):
    """Plot probability density estimation based on app_eff_df dataframe onto axis ax.
    Add plot handles (for legend purposes) to handles if they are not already present.
    Use order & colors found in list of (color, name) tuples if present, otherwise throw something together.
    Use symlog y axis in if symlog is true; otherwise use linear."""
    ax.set_aspect(0.15)
    if plat_colors is None:
        plat_colors = []
        qual_colormap = plt.get_cmap("tab10")
        for i, name in enumerate(app_eff_df.columns[1:]):
            plat_colors.append((qual_colormap(i), name))
    for color, name in plat_colors:
        data = app_eff_df[name][1:]
        d = sorted(data)
        l_akde = akde(np.linspace(0, 1, 1000), d, 0.05)
        fs = l_akde.pdf_refine(10)
        extended_x = [-0.035] + list(l_akde.x) + [1.035]
        extended_y = [fs[0]] + list(fs) + [fs[-1]]
        h = ax.plot(extended_x,
                    extended_y,
                    label=name,
                    color=color,
                    clip_on=False)[0]
        if name not in handles:
            handles[name] = h
    if symlog:
        plt.yscale('symlog', subs=range(10))
    else:
        ax.set_aspect(0.01)
    plt.grid(True)
    plt.xlim([0, 1])
    ax.yaxis.grid(True, which='minor')
    if symlog:
        plt.ylabel("Density (symlog)")
    else:
        plt.ylabel("Density")
    plt.xlabel("Efficiency")
    return handles


def histogram(bins, data):
    """Compute and return 1D histogram of samples in data into bins, where bins is a list of n boundaries for n+1 bins.
    Drop samples that fall outside bins. Each bin counts the values at its right endpoint inclusively, except bin 0 which has both."""
    z = np.zeros(len(bins) - 1)
    for d in data:
        if d < bins[0]:
            continue
        for i, b in enumerate(bins[1:]):
            if d <= b:
                z[i] += 1.0
                found = True
                break
    return z


def binplot(ax, app_effs, colordict=None):
    """Compute and plot histogram of dataframe app_effs onto axis ax. Use colors for each column as specified in colordict or compute manually.
    Bin 0 is handled specially and kept separate from others."""
    bins = np.arange(0, 1.1, 0.1, dtype=np.float)
    bins[0] = np.finfo(float).eps
    bins = np.append(np.zeros(1), bins)
    bar_data = {}
    for name in app_effs.columns[1:]:
        data = app_effs[name]
        bar_data[name] = histogram(bins, data)
        bar_data[name] = bar_data[name] / bar_data[name].sum() * 100.0

    bin_offsets = 2 * np.array(range(len(bins) - 1))

    handles = []
    width = float(1.0) / len(bar_data.items())
    for i, (name, data) in enumerate(list(bar_data.items())):
        pbins = float(i) * width + width / 2.0 + bin_offsets
        if colordict:
            res = ax.bar(pbins,
                         height=data,
                         width=width,
                         color=colordict[name])
        else:
            res = ax.bar(pbins, height=data, width=width)
        handles.append(res.patches[0])
        handles[-1].set_label(name)
    plt.ylabel('Frequency in %')
    plt.xlabel('Efficiency')
    plt.grid(axis='y')

    ax.set_ylim([0, 100.0])

    ax.set_xticks(bin_offsets + 0.5)
    # Rename the first bin
    locs, labels = plt.xticks()
    labels[0] = "Did not run"
    for i, _ in enumerate(labels):
        if i == 0:
            continue
        labels[i] = f"({round(bins[i],3)}, {round(bins[i+1],3)}]"
    plt.xticks(locs, labels)

    labels = ax.get_xticklabels()
    ax.set_xticklabels(labels, rotation=45, ha="right", rotation_mode="anchor")
    return handles


def plot_cascade(fig,
                 gs,
                 index,
                 app_eff_df,
                 handles,
                 app_colors=None,
                 plat_colors=None):
    """Plot efficiency cascade & platform chart on figure/gridspec fig/gs with gridspec index index.
    app_eff_df is input dataframe. Handles is a dict of column names to handles for legends, which is updated.
    app_colors is a dictionary of column names to colors; if not present, a heuristic is used.
    plat_colors is a list of (color, platform_name) pairs to use in the platform chart. One is created if it is not passed in."""
    subgrid = gridspec.GridSpecFromSubplotSpec(
        2, 1, subplot_spec=gs[index[0], index[1]], hspace=0, height_ratios=[5, 1])
    qual_colormap = plt.get_cmap("tab10")
    ax2 = fig.add_subplot(subgrid[1, :])
    ax = fig.add_subplot(subgrid[0, :], sharex=ax2)

    if plat_colors is None:
        plat_colors = []
        qual_colormap = plt.get_cmap("tab10")
        for i, name in enumerate(app_eff_df.columns[1:]):
            plat_colors.append((qual_colormap(i), name))

    min_plat = None
    max_plat = None
    appinfo = {}
    for i, name in enumerate(app_eff_df.columns[1:]):
        in_effs = list(zip(app_eff_df[app_eff_df.columns[0]], app_eff_df[name]))
        cascade = pp_cdf_raw_effs(in_effs)

        effs, pps, plats = zip(*cascade)

        ppl = list(enumerate(reversed(pps), 1))
        ppl = ppl + [(ppl[-1][0], 0.0)]
        data_pp = np.asarray(ppl)
        effl = list(enumerate(reversed(effs), 1))
        effl = effl + [(effl[-1][0], 0.0)]
        data_eff = np.asarray(effl)

        center = data_pp[:, 0]

        lo = center - 0.5
        hi = center + 0.5
        if min_plat is None or center[0] < min_plat:
            min_plat = center[0]
        if max_plat is None or center[-1] > max_plat:
            max_plat = center[-1]

        if app_colors is None or name not in app_colors:
            color = qual_colormap(i)
        else:
            color = app_colors[name]
        appinfo[name] = (data_pp, data_eff, plats, center, i, color)
    for name, (data_pp, data_eff, plats, center, i, color) in appinfo.items():
        name = name.replace(r"\%", "%")
        eff_name = f"{name} eff."
        pp_name = f"{name} PP"

        pp_h = ax.plot(center,
                       data_pp[:,
                               1],
                       label=pp_name,
                       color=color,
                       lw=3,
                       marker="s",
                       ls='dashed')[0]
        eff_h = ax.plot(center,
                        data_eff[:,
                                 1],
                        label=eff_name,
                        color=color,
                        marker="o",
                        lw=3)[0]

        colors = [plat_colors[p] for p in plats]
        fac = 0.25
        ax2.bar(center[:-1],
                height=fac,
                width=1.0,
                bottom=i * fac,
                color=colors,
                edgecolor=color,
                linewidth=0,
                alpha=1.0)

        ax2.bar([0.0, max_plat + 1.0], height=fac,
                width=1.0, bottom=i * fac, color=color)

        if eff_name not in handles:
            handles[eff_name] = eff_h
        if pp_name not in handles:
            handles[pp_name] = pp_h

    ax.set_ylabel("App PP (dashed)/efficiency (solid)")
    ax2.set_xlabel("# of platforms")
    ax2.set_xlim([0, max_plat + 1])
    ax2.set_ylim([0, len(appinfo) * fac])
    ax.set_ylim([0, 1.1])
    ax2.set_xticks(np.arange(min_plat, max_plat + 1))
    ax2.set_yticks([])
    ax.label_outer()
    ax.xaxis.set_ticks_position('none')
    ax2.axvline(min_plat - 0.5, color="black")
    ax2.axvline(max_plat + 0.5, color="black")
    ax.grid(True)
    return ax


def boxplot(ax, effs_pd):
    """Plot a a box-and-whisker plot of the dataframe effs_pd onto ax."""
    ax.boxplot(effs_pd[effs_pd.columns[1:]].to_numpy(),
               notch=False,
               whiskerprops=dict(color="#5799c6"),
               boxprops=dict(color="#5799c6"),
               medianprops=dict(linestyle='-',
                                linewidth=3.0))
    ax.set(ylabel='Efficiency')
    ax.grid(True)
    labels = effs_pd.columns[1:].tolist()
    ax.set_xticklabels(labels, rotation=45, ha="right", rotation_mode="anchor")
    labels = ax.get_xticklabels()
    for i in range(len(labels)):
        if not plt.rcParams['text.usetex']:
            labels[i].set_text(labels[i].get_text().replace(r"\%", "%"))


def save_and_report(filename, exts):
    """Save current figure to filename.exts for each extension in sequence exts. Also print progress."""
    for x in exts:
        of = f"{filename}.{x}"
        plt.savefig(of, bbox_inches="tight")
        print(f"Wrote {of}.")


if __name__ == '__main__':
    import sys
    import argparse

    legal_extensions = set(['png', 'pdf'])
    legal_vis = set(['box', 'bins', 'casc', 'epdf'])

    desc = "Performance portability visualization demonstration"
    parser = argparse.ArgumentParser(description=desc)
    parser.add_argument("-r",
                        "--raw-effs",
                        dest='raw_effs',
                        action='store_true',
                        default=False,
                        help='Interpret csv contents as raw efficiencies.')
    parser.add_argument("-t",
                        "--throughput",
                        dest='throughput',
                        action='store_true',
                        default=False,
                        help='Interpret csv contents throughput numbers.')
    parser.add_argument("-o",
                        "--output-prefix",
                        dest='oprefix',
                        action='store',
                        default="./",
                        help='Write output files with a specific prefix')
    parser.add_argument("-F",
                        "--ofile-format",
                        dest='ofile_fmt',
                        metavar=f'[{"|".join(legal_extensions)}]+',
                        action='store',
                        default="pdf",
                        help='Type of output files to produce.')
    parser.add_argument("-V",
                        "--vis-types",
                        dest='vis_types',
                        metavar=f'[{"|".join(legal_vis)}]+',
                        action='store',
                        default="box,bins,casc,epdf",
                        help='Visualizations to produce.')
    parser.add_argument('csvfiles',
                        metavar='<CSV-FILE>+',
                        nargs=argparse.REMAINDER)

    args = parser.parse_args()

    if args.raw_effs and args.throughput:
        print("Asked to intrepret CSV as both raw eff. & throughput!")
        sys.exit(1)

    if len(args.csvfiles) == 0:
        print("No input files specified.")
        sys.exit(1)

    output_extensions = set()
    for t in args.ofile_fmt.split(','):
        if t.lower() in legal_extensions:
            if t in output_extensions:
                printf("Warning: duplicate output extension found. Skipping.")
            else:
                output_extensions.add(t)

    if len(output_extensions) == 0:
        print("Warning: no output extensions found; no output will be written")

    vis_types = set()
    for vt in args.vis_types.split(','):
        if vt.lower() in legal_vis:
            if vt in vis_types:
                print("Warning: duplicate vis type found. Skipping.")
            else:
                vis_types.add(vt)

    for filename in args.csvfiles:

        effs_df = app_effs(filename,
                           raw_effs=args.raw_effs,
                           throughput=args.throughput)

        plats = effs_df[effs_df.columns[0]]

        output_base = args.oprefix + Path(filename).stem

        if 'casc' in vis_types:

            # Eff. cascade

            plat_colors = {}
            plat_handles = []
            plat_cmap = plt.get_cmap("summer")
            for i, p in enumerate(plats):
                plat_colors[p] = plat_cmap(float(i) / (len(plats) - 1))
                plat_handles.append(mpatches.Patch(color=plat_colors[p],
                                                   label=p))

            fig = plt.figure(figsize=(4, 4))
            handles = {}
            gs = fig.add_gridspec(1, 1)
            plot_cascade(fig, gs, [0, 0], effs_df, handles,
                         app_colors=None, plat_colors=plat_colors)

            handle_names, handle_lists = zip(*handles.items())
            fig.legend(handle_lists,
                       handle_names,
                       loc='upper left',
                       bbox_to_anchor=(1.0, 1.0),
                       ncol=1,
                       handlelength=2.0)
            fig.legend(handles=plat_handles,
                       loc='lower left',
                       bbox_to_anchor=(1.0, 0.1),
                       ncol=3,
                       handlelength=1.0)
            plt.tight_layout(pad=0.4, w_pad=0.5, h_pad=1.0)
            save_and_report(f"{output_base}_eff_cascade", output_extensions)

        if 'epdf' in vis_types:
            # PDF
            fig = plt.figure(figsize=(5, 4))
            ax = fig.add_subplot(1, 1, 1)

            handles = plot_pdf(ax, effs_df, {}, symlog=True)
            plt.tight_layout(pad=0.4, w_pad=1.5, h_pad=0.5)
            plt.legend(loc="upper center", handlelength=0.5, labels=handles)
            save_and_report(f"{output_base}_estimated_density_chart",
                            output_extensions)

        if 'box' in vis_types:
            # Box plot
            fig = plt.figure(figsize=(5, 4))
            ax = fig.add_subplot(1, 1, 1)
            boxplot(ax, effs_df)
            plt.tight_layout(pad=0.4, w_pad=1.5, h_pad=0.5)
            save_and_report(f"{output_base}_box_chart", output_extensions)

        if 'bins' in vis_types:
            # Bins

            fig = plt.figure(figsize=(5, 4))
            ax = fig.add_subplot(1, 1, 1)

            binplot(ax, effs_df, False)
            L = plt.legend()
            texts = [m.get_text().replace(r"\%", "%") for m in L.get_texts()]
            plt.tight_layout(pad=0.4, w_pad=1.5, h_pad=0.5)
            plt.legend(loc="upper center", handlelength=0.5, labels=texts)
            save_and_report(f"{output_base}_binned_chart", output_extensions)
