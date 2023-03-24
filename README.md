# gb-lad-cluster-analysis

This script takes the [subnational indicators dataset from the ONS](https://www.ons.gov.uk/peoplepopulationandcommunity/wellbeing/datasets/subnationalindicatorsdataset) and processes into a table of all available indicators. The indicators are then scaled to have a mean of 0 and unit variance and then a probabilisitic PCA is fit using the `PCAmethods` package.
Finally, local authorities are clustered together using K-means clustering and plotted.

## Usage instructions

In order to run the script, you will need to download the subnational indicators dataset (linked above) and place it in a directory called `data`. You must also download a local authority boundaries shapefile from the [Open Geography Portal](https://geoportal.statistics.gov.uk/maps/local-authority-districts-december-2022-boundaries-uk-bgc) and place the unzipped contents in a folder called `boundaries`. Finally, create a folder called `outputs` where the PCA loadings and the plot will be saved.
