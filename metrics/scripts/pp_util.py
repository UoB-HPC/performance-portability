# Copyright (c) 2020 Performance Portability authors
# SPDX-License-Identifier: MIT

from csv import DictReader, reader
import attr

def harmean(vals):
    try:
        s = sum((1.0/x for x in vals))
    except ZeroDivisionError:
        return 0.0
    return len(vals)/s

@attr.s
class platform(object):
    name = attr.ib()
    arch_bw = attr.ib()
    types = attr.ib(default=attr.Factory(list))
    best_bw = attr.ib(default=None)
    def arch_eff(self, perf, throughput):
        if throughput:
            return perf/self.arch_bw
        else:
            return self.arch_bw/perf
    def app_eff(self, perf, throughput):
        if throughput:
            return perf/self.best_bw
        else:
            return self.best_bw/perf

global platforms

platforms = dict()

def add_platform(name, arch_bw, types):
    platforms[name] = platform(name, float(arch_bw), types)

@attr.s
class perf_entry(object):
    platform = attr.ib()
    perf = attr.ib()

@attr.s
class app(object):
    name = attr.ib()
    perfs = attr.ib(default=attr.Factory(dict))
    @classmethod
    def entries(cls, name, perf_pairs):
        perfs = dict()
        for k, v in perf_pairs:
            perfs[k] = perf_entry(k,float(v))
        return cls(name, perfs)
    def bad_pp_arch(self):
        return harmean([platforms[v.platform].arch_eff(v.perf) for v in self.perfs.values()])
    def bad_pp_app(self):
        return harmean([platforms[v.platform].app_eff(v.perf) for v in self.perfs.values()])
    def arch_pp(self, plats, throughput):
        try:
            vals = [platforms[k].arch_eff(self.perfs[k].perf, throughput) for k in plats]
            return harmean(vals)
        except KeyError:
            return 0.0
    def app_pp(self, plats, throughput):
        try:
            vals = [platforms[k].app_eff(self.perfs[k].perf, throughput) for k in plats]
            return harmean(vals)
        except KeyError:
            return 0.0

global apps

apps = dict()

def add_app(name, pairs):
    apps[name] = app.entries(name, pairs)

def best_plat_perf(plat_name, apps, throughput):
    best = None
    for a in apps:
       for p, v in a.perfs.items():
           if p == plat_name:
               if throughput:
                   if best == None or best < v.perf:
                       best = v.perf
               else:
                   if best == None or best > v.perf:
                       best = v.perf
    return best

def load_app_perfs(appfile, appname=None, throughput=False):
    global apps
    apps=dict()
    global platforms
    platforms=dict()
    with open("../data/spec.csv", "r") as fp:
        plats = DictReader(fp, skipinitialspace=True)
        plat_dict = {}
        for row in plats:
            plat_dict[row["Architecture"]] = row
            add_platform(row["Architecture"], float(row['Mem BW']), row['Category'])
    with open(appfile, "r") as fp:
        perfs = reader(fp, skipinitialspace=True)
        header = [x.strip() for x in next(perfs)]
        for row in perfs:
            if len(row) == 0:
                break
            plat = row[0]
            for i, item in enumerate(row[1:]):
                appname = header[i+1]
                if appname not in apps:
                    apps[appname] = app(appname)
                if item.strip() == 'X':
                    if throughput:
                        item = 0.0
                    else:
                        item = "inf"
                apps[appname].perfs[plat] = perf_entry(plat, float(item))
    for p in list(platforms.values()):
        p.best_bw = best_plat_perf(p.name, apps.values(), throughput)
        if p.best_bw == 0.0:
            del platforms[p.name]

def get_effs(appfile, appname=None, throughput=False):
    global apps
    global platforms
    load_app_perfs(appfile, appname, throughput)
    res = {}
    for name,theapp in apps.items():
        res[name] = [x[1] for x in app_effs(theapp, list(platforms.keys()), throughput)]
    return res

def read_effs(appfile):
    global apps
    apps = {}
    with open(appfile, "r") as fp:
        perfs = reader(fp, skipinitialspace=True)
        header = [x.strip() for x in next(perfs)]
        for row in perfs:
            plat = row[0]
            for i, item in enumerate(row[1:]):
                appname = header[i+1]
                if appname not in apps:
                    apps[appname] = []
                apps[appname].append((plat, float(item)/100.0))
    s = sorted(list(apps.items()), key=lambda x: harmean([i[1] for i in x[1]]))
    return s

def app_effs(theapp, plats, throughput):
    perfs = []
    for p in plats:
        if p in theapp.perfs:
            perfs.append(theapp.perfs[p])
    valid_perfs = []
    for p in perfs:
        if p.platform in plats:
            if p.perf > 0 and p.perf != float("inf"):
                valid_perfs.append((p, platforms[p.platform].app_eff(p.perf, throughput)))
            else:
                valid_perfs.append((p, 0.0))
    return valid_perfs

import numpy

def gaussian(x):
    return 1.0/numpy.sqrt(2.0*numpy.pi)*numpy.exp(-0.5*x**2.0)

from scipy.special import erf
from scipy.integrate import simps

def gaussian_cdf(x):
    return 0.5*(1.0+erf(x*2**-0.5))

def gaussian_scaling(a, b):
    return -2.0/(erf(a*2**-0.5)+erf(-b*2**-0.5))

class gaussian_family:
    def __init__(self):
        self.kernel_func = gaussian
        self.scaling_func = gaussian_scaling
        self.cdf_func = gaussian_cdf

def bw_estimate(samples):
    sigma = numpy.std(samples)
    cand = ((4*sigma**5.0)/(3.0*len(samples)))**(1.0/5.0)
    if cand < 1e-7:
        return 1.0
    return cand

class akde:
    def __init__(self, x, samples, bw_fac):
        self.clip = True
        self.kernel_family = gaussian_family()
        self.bw_fac = bw_fac
        self.x = x
        self.samples = samples
        self.last_pdf = None
        self.bw0 = bw_estimate(samples)

    def bw_estimate(self, lx):
        if self.last_pdf is None:
            return self.bw0

        return self.bw_fac*(self.density_estimate(lx)**-0.5)

    def density_estimate(self, lx):
        assert self.last_pdf is not None

        loc = numpy.searchsorted(self.x, lx)
        if loc >= len(self.last_pdf):
            return self.last_pdf[-1]
        else:
            return self.last_pdf[loc]

    def pdf(self):
        scaling_func = self.kernel_family.scaling_func
        kernel_func = self.kernel_family.kernel_func
        pdf = numpy.zeros(len(self.x))
        for s in self.samples:
            loc_h = self.bw_estimate(s)
            if self.clip:
                assert s >= self.x[0] and s <= self.x[-1]
                scaling = scaling_func((self.x[0]-s)/loc_h, (self.x[-1]-s)/loc_h)
            else:
                scaling = 1.0
            pdf += 1.0/loc_h * scaling * kernel_func((self.x-s)/loc_h)
        pdf = pdf/len(self.samples)
        self.last_pdf = pdf
        area = simps(pdf, self.x)
        if self.clip:
            assert numpy.fabs(area-1.0) < 1e-3
        return pdf, area

    def pdf_series(self, num):
        self.last_pdf = None
        res = []
        for i in range(num):
            pdf, area = self.pdf()
            res.append(pdf)
        return res

    def pdf_refine(self, num):
        self.last_pdf = None
        for i in range(num):
            pdf, area = self.pdf()
        return pdf

    def cdf(self):
        scaling_func = self.kernel_family.scaling_func
        cdf_func = self.kernel_family.cdf_func
        cdf = numpy.zeros(len(self.x))
        for s in self.samples:
            loc_h = self.bw_estimate(s)
            if self.clip:
                assert s >= self.x[0] and s <= self.x[-1]
                scaling = scaling_func((self.x[0]-s)/loc_h, (self.x[-1]-s)/loc_h)
            else:
                scaling = 1.0
            cdf +=  scaling * (cdf_func((self.x-s)/loc_h)-cdf_func((self.x[0]-s)/loc_h))
        return cdf/len(self.samples)

def pp_cdf(theapp, plats, throughput):
    perfs = []
    for p in plats:
        if p in theapp.perfs:
            perfs.append(theapp.perfs[p])
    valid_perfs = []
    for p in perfs:
        if p.platform in plats:
            if p.perf > 0 and p.perf != float("inf"):
                valid_perfs.append((p, platforms[p.platform].app_eff(p.perf, throughput)))
    sorted_perfs = sorted(valid_perfs, key=lambda x: x[1])
    res = []
    for i in range(len(sorted_perfs)):
        res.append((sorted_perfs[i][1], harmean([x[1] for x in sorted_perfs[i:]]), sorted_perfs[i][0]))
    return res

def pp_cdf_raw_effs(theapp):
    valid_effs = [ x for x in theapp  if x[1] > 0 and x[1] != float("inf")]
    sorted_effs = sorted(valid_effs, key=lambda x: x[1])
    res = []
    for i in range(len(sorted_effs)):
        res.append((sorted_effs[i][1], harmean([x[1] for x in sorted_effs[i:]]), sorted_effs[i][0]))
    return res

from matplotlib import pylab as plt
import matplotlib.gridspec as gridspec
from pathlib import Path

def plot_pdf(ax, app_eff, handles, plat_colors=None, symlog=True):
    ax.set_aspect(0.15)
    if plat_colors is None:
        plat_colors = []
        qual_colormap = plt.get_cmap("tab10")
        for i, name in enumerate(app_eff.keys()):
            plat_colors.append((qual_colormap(i), name))
    for color, name in plat_colors:
        if name not in app_eff:
            continue
        data  = app_eff[name]
        d = sorted(data)
        l_akde = akde(numpy.linspace(0,1,1000), d, 0.05)
        fs = l_akde.pdf_refine(10)
        extended_x = [-0.035] + list(l_akde.x) + [1.035]
        extended_y = [fs[0]] + list(fs) + [fs[-1]]
        h = ax.plot(extended_x,extended_y,label=name, color=color,clip_on=False)[0]
        if name not in handles:
            handles[name] = h
    if symlog:
        plt.yscale('symlog', subsy=range(10))
    else:
        ax.set_aspect(0.01)
    plt.grid(True)
    plt.xlim([0,1])
    ax.yaxis.grid(True, which='minor')
    if symlog:
        plt.ylabel("Density (symlog)")
    else:
        plt.ylabel("Density")
    plt.xlabel("Efficiency")

def plot_bins(ax, app_eff, handles, plat_colors=None):
    app_eff = app_eff
    if plat_colors is None:
        plat_colors = []
        qual_colormap = plt.get_cmap("tab10")
        for i, name in enumerate(app_eff.keys()):
            plat_colors.append((qual_colormap(i), name))
    width=0.1
    bins= numpy.linspace(0,1,10)
    plat_ct = len(plat_colors)
    for idx, (color, name) in enumerate(plat_colors):
        if name not in app_eff:
            continue
        data  = app_eff[name]
        d = sorted(data)
        histo = numpy.histogram(d, bins=bins, density=True)
        h = ax.bar(histo[1][:-1] + idx*width/plat_ct, histo[0], width=width/plat_ct, color=color)
        if name not in handles:
            handles[name] = h
    plt.grid(True)
    plt.xlim([0,1])
    ax.yaxis.grid(True, which='minor')
    plt.ylabel("Density")
    plt.xlabel("Efficiency")

def plot_cascade(fig, gs, index, app_eff, appname, handles, app_colors=None, plat_colors=None):
    subgrid=gridspec.GridSpecFromSubplotSpec(2,1,subplot_spec=gs[index[0],index[1]],hspace=0, height_ratios=[5,1])
    qual_colormap = plt.get_cmap("tab10")
    ax2 = fig.add_subplot(subgrid[1,:])
    ax = fig.add_subplot(subgrid[0,:],sharex=ax2)

    if plat_colors is None:
        plat_colors = []
        qual_colormap = plt.get_cmap("tab10")
        for i, name in enumerate(app_eff.keys()):
            plat_colors.append((qual_colormap(i), name))

    min_plat = None
    max_plat = None
    appinfo = {}
    for i, (name, in_effs) in enumerate(app_eff):

        cascade = pp_cdf_raw_effs(in_effs)

        effs, pps, plats = zip(*cascade)

        ppl = list(enumerate(reversed(pps),1))
        ppl =  ppl + [(ppl[-1][0], 0.0)]
        data_pp = numpy.asarray(ppl)
        effl = list(enumerate(reversed(effs),1))
        effl =  effl + [(effl[-1][0], 0.0)]
        data_eff = numpy.asarray(effl)

        center = data_pp[:,0]

        lo = center-0.5
        hi = center+0.5
        if min_plat == None or center[0] < min_plat:
            min_plat = center[0]
        if max_plat == None or center[-1] > max_plat:
            max_plat = center[-1]

        if app_colors is None or name not in app_colors:
            color = qual_colormap(i)
        else:
            color = app_colors[name]
        appinfo[name] = (data_pp, data_eff, plats, center, i, color)
    for name, (data_pp, data_eff, plats, center, i, color) in appinfo.items():
        name = name.replace(r"\%", "%")
        eff_name=f"{name} eff."
        pp_name=f"{name} PP"

        pp_h = ax.plot(center,data_pp[:,1], label=pp_name, color=color, lw=3, marker="s", ls='dashed')[0]
        eff_h = ax.plot(center,data_eff[:,1], label=eff_name, color=color, marker="o", lw=3)[0]

        colors = [plat_colors[p] for p in plats]
        fac=0.25
        ax2.bar(center[:-1], height=fac, width=1.0,bottom=i*fac,color=colors,edgecolor=color, linewidth=0, alpha=1.0)

        ax2.bar([0.0, max_plat+1.0], height=fac, width=1.0,bottom=i*fac,color=color)

        if eff_name not in handles:
            handles[eff_name] = eff_h
        if pp_name not in handles:
            handles[pp_name] = pp_h

    ax.set_ylabel("App PP (dashed)/efficiency (solid)")
    ax2.set_xlabel("# of platforms")
    ax2.set_xlim([0,max_plat+1])
    ax2.set_ylim([0,len(appinfo)*fac])
    ax.set_ylim([0,1.1])
    ax2.set_xticks(numpy.arange(min_plat, max_plat+1))
    ax2.set_yticks([])
    ax.label_outer()
    ax.xaxis.set_ticks_position('none')
    ax2.axvline(min_plat-0.5,color="black")
    ax2.axvline(max_plat+0.5,color="black")
    ax.grid(True)
