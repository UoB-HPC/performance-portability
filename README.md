Performance Portability Utilities
=================================

This repository contains various data, scripts, and utilities for the study of performance portability (and productivity). It began with a collaboration between researchers at the University of Bristol and at Intel, and it is the original authors' hope that this material will help others in their exploration of this growing area of interest.  We welcome contributions!

## Organization ##

The repository is arranged as follows:

    <root>
        AUTHORS                 # A list of contributors
        benchmarking/           # Performance portability data, organized by year and application, formatting in csv
        images/                 # A placeholder directory for output from scripts
        LICENSE                 # The software license governing the software in this repository
        metrics/
            data/               # Collated benchmark data in csv files, to be fed to scripts
            scripts/            # Processing scripts
                averages.py     # Compute different types of averages from datasets
                consistency.py  # Compute different types of variance/consistency-tracking scores from datasets
                heatmap.py      # Draw efficiency heatmaps
                pp_util.py      # Compute efficiency and PP, contains adaptive kernel estimation computations
                *.ipynb

## Jupyter Notebooks ##

[Jupyter](jupyter.org "Jupyter website") is a web-based interactive framework for developing and presenting code, images, and equations in an integrated fashion. The `.ipynb` files in this repository are Jupyter notebooks used to produce the figures in the paper and presentations.

## `pp_vis.py` ##

The `pp_vis.py` script contains implementations of the various visualization methods discussed in the companion paper. We hope it will prove useful to the community, both as a tool for evaluating datasets and as a springboard for new visualization and evaluation techniques.

The script can be used as a module for more sophisticated usage (as in the companion Jupyter notebooks), and can be used from the command line to generate plots.

This requires Python 3.7 or higher, Pandas 1.0 or higher, matplotlib, numpy, and scipy. These may be installed with pip or your local package manager.

Command-line usage is self-documenting with the `$ ./pp_vis.py -h` option, but to get started with the example data, try this:

    $ ./pp_vis.py --raw-effs -F pdf ../data/synthetic.csv
    Wrote ./synthetic_eff_cascade.pdf.
    Wrote ./synthetic_estimated_density_chart.pdf.
    Wrote ./synthetic_box_chart.pdf.
    Wrote ./synthetic_binned_chart.pdf.

    $ ./pp_vis.py --throughput -F pdf ../data/babelstream.csv
    Wrote ./babelstream_eff_cascade.pdf.
    Wrote ./babelstream_estimated_density_chart.pdf.
    Wrote ./babelstream_box_chart.pdf.
    Wrote ./babelstream_binned_chart.pdf.

    $ ./pp_vis.py -F pdf ../data/neutral.csv ../data/minifmm.csv ../data/tealeaf.csv ../data/cloverleaf.csv
    Wrote ./neutral_eff_cascade.pdf.
    Wrote ./neutral_estimated_density_chart.pdf.
    Wrote ./neutral_box_chart.pdf.
    Wrote ./neutral_binned_chart.pdf.
    Wrote ./minifmm_eff_cascade.pdf.
    Wrote ./minifmm_estimated_density_chart.pdf.
    Wrote ./minifmm_box_chart.pdf.
    Wrote ./minifmm_binned_chart.pdf.
    Wrote ./tealeaf_eff_cascade.pdf.
    Wrote ./tealeaf_estimated_density_chart.pdf.
    Wrote ./tealeaf_box_chart.pdf.
    Wrote ./tealeaf_binned_chart.pdf.
    Wrote ./cloverleaf_eff_cascade.pdf.
    Wrote ./cloverleaf_estimated_density_chart.pdf.
    Wrote ./cloverleaf_box_chart.pdf.
    Wrote ./cloverleaf_binned_chart.pdf.

Data is expected to be in comma-separated csv format, with the first column being a list of platform names and each successive column the containing an application, with the results for each platform. An 'x' or 'X' may be used indicate that a platform did not run. By default, it is assumed that the input is in time-to-solution, but with the `--throughput` flag, this may be changed to be throughput. With the `--raw-effs` flag, the data is assumed to be in percentage efficiency already.

Multiple csv files can be passed in at once; all options are applied to each input..

## For More Information

The performance portability metric computed by these scripts was first proposed in the following two papers:
- S.J. Pennycook, J.D. Sewall and V.W. Lee, "[A Metric for Performance Portability](https://arxiv.org/abs/1611.07409)", in Proceedings of the 7th International Workshop in Performance Modeling, Benchmarking and Simulation of High Performance Computer Systems (PMBS), 2016
- S.J. Pennycook, J.D. Sewall and V.W. Lee, "[Implications of a Metric for Performance Portability](https://doi.org/10.1016/j.future.2017.08.007)", in Future Generation Computer Systems, Volume 92, March 2019, Pages 947-958

The datasets used here were originally collected for the following paper, which also served as the inspiration for the efficiency cascade plots:
- T. Deakin et al., "[Performance Portability Across Diverse Computer Architectures](https://doi.org/10.1109/P3HPC49587.2019.00006)", in Proceedings of the 2019 IEEE/ACM International Workshop on Performance, Portability and Productivity in HPC (P3HPC), 2019
