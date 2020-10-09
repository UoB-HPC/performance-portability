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
                *.ipynb         # Jupyter Notebooks used to generate visualizations in paper & presentations
                averages.py     # Compute different types of averages from datasets
                binned_chart.py # Draw histograms from datasets
                box_plot.py     # Draw box plots from datasets
                calculator.py   # Compute PP scores and format tables
                consistency.py  # Compute different types of variance/consistency-tracking scores from datasets
                heatmap.py      # Draw efficiency heatmaps
                pp_util.py      # Compute efficiencies and PP, contains adaptive kernel estimation computations
                violin_plot.py  # Draw violin plots from datasets

## Jupyter Notebooks ##

[Jupyter](jupyter.org "Jupyter website") is a web-based interactive framework for developing and presenting code, images, and equations in an integrated fashion. The `.ipynb` files in this repository are Jupyter notebooks used to produce the figures in the paper and presentations.

## For More Information

The performance portability metric computed by these scripts was first proposed in the following two papers:
- S.J. Pennycook, J.D. Sewall and V.W. Lee, "[A Metric for Performance Portability](https://arxiv.org/abs/1611.07409)", in Proceedings of the 7th International Workshop in Performance Modeling, Benchmarking and Simulation of High Performance Computer Systems (PMBS), 2016
- S.J. Pennycook, J.D. Sewall and V.W. Lee, "[Implications of a Metric for Performance Portability](https://doi.org/10.1016/j.future.2017.08.007)", in Future Generation Computer Systems, Volume 92, March 2019, Pages 947-958

The datasets used here were originally collected for the following paper, which also served as the inspiration for the efficiency cascade plots:
- T. Deakin et al., "[Performance Portability Across Diverse Computer Architectures](https://doi.org/10.1109/P3HPC49587.2019.00006)", in Proceedings of the 2019 IEEE/ACM International Workshop on Performance, Portability and Productivity in HPC (P3HPC), 2019
