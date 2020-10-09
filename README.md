Performance Portability utilties
================================

This repository contains various data, scripts, and utiltites for the study of performance portability (and productivity). It began with a collaboration between researchers at the University of Bristol and at Intel, and it is the original authors' hope that this material will help others in there exploration of this growing area of interest.  We welcome contributions!

## Organization ##

The respository is arranged as follows:

    <root>
        AUTHORS                 # a list of contributors
        benchmarking/           # Performance portability data, organized by year and application, formatting in csv
        images/                 # A placeholder directory for output from scripts
        LICENSE                 # The software license governing the software in this repository
        metrics/
            data/               # Collated benchmarked data in csv file to be fed to scripts
            scripts/            # Processing scripts
                *.ipynb         # Jupyter Notebooks used to generate visualizations in paper & presentations
                averages.py     # Draws different types of averages from datasets
                binned_chart.py # Draws histograms from datasets
                box_plot.py     # Draws box plots from datasets
                calculator.py   # Compute PP scores and formats tables
                consistency.py  # Compute different types of variance/consisteny-tracking scores from datasets
                heatmap.py      # Draws efficiency heatmaps
                pp_util.py      # Computes efficiencies and pp, contains adapative kernel estimation computations
                violin_plot.py  # Draws violin plots from datasets

## Jupyter notebooks ##

[Jupyter](jupyter.org "Jupyter website") is a web-based interactive framework for developing and presenting code, and images, and equations in an integrated fashion. The `.ipynb` files in this repository are Jupyter notebooks used to produce the figures in the paper and presentations.
