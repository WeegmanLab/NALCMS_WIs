#!/bin/bash
#SBATCH --job-name=rasterize_us
#SBATCH --output=logs/rasterize_us_%j.out
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=2000G
#SBATCH --time=2-00:00:00

## notifications
#SBATCH --mail-user=erika.garcezdarocha@usask.ca  # specify your email address for notifications
#SBATCH --mail-type=ALL  # which type of notifications to send

# load modules then display what we have 
module load StdEnv/2023
module load gcc/12.3
module load r/4.4.0
module load r-bundle-bioconductor/3.20

Rscript rasterize_us.R 
