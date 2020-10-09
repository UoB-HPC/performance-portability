Performance Portability Utilities
=================================

This repository contains various data, scripts, and utilities for the study of performance portability (and productivity). It began with a collaboration between researchers at the University of Bristol and at Intel, and it is the original authors' hope that this material will help others in there exploration of this growing area of interest.  We welcome contributions!

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
