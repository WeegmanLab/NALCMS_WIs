#***********************************************************************************************************
#  
# Project: Land cover + Wetlands
# Description: Plot final raster NALCMS + WI
# Date: 3 July 2025
# Author: Érika Garcez da Rocha
#
#**********************************************************************************************************************************
#**********************************************************************************************************************************

rm(list=ls())

# Load packages ####
# Packages list 
pkgs <- c("tictoc","dplyr")

# Load all packages and suppress messages
invisible(lapply(pkgs, function(pkg) suppressMessages(library(pkg, character.only = TRUE))))

# Log ####
# Create log file connection #
log_path <- "./logs/plotmap_log.txt"
log_con <- file(log_path, open = "wt")
sink(log_con, split = TRUE)       # Redirect output to both console and file
sink(log_con, type = "message")   # Redirect messages to file

tic.clearlog()
tic.log(format = TRUE)  # This makes `tic()`/`toc()` log messages printable
message("Starting script: ", Sys.time())

# Read NALCMS+WI raster ####
tic("Read NALCMS+WI raster")
r <- terra::rast("./output/nalcms_updated.tif")
crs_r <- terra::crs(r)
toc()

# Convert raster to factor to color based on palette defined ####
tic("Convert raster to factor")
r_fact <- terra::as.factor(r)
toc()

# Get legend colour palette ####
tic("Get legend colours")
legend_df <- read.csv("raster_legend.csv")
# Create color vectors 
rgb_to_hex <- function(r, g, b) sprintf("#%02X%02X%02X", r, g, b)
colors_vec <- mapply(rgb_to_hex, legend_df$r, legend_df$g, legend_df$b)
# Define levels 
levels(r_fact) <- data.frame(ID = legend_df$value, label = legend_df$name)
toc()

# Plot ####
tic("Plot raster")
png("landcover_map.png", width = 1200, height = 800, res = 150)  # ajuste tamanho e resolução
par(oma = c(1, 1, 1, 13))  
terra::plot(r_fact, col = colors_vec, legend = TRUE, main = "NALCMS + WIs Land Cover Map")
dev.off()
toc()
# Log ####
# Save tic log output
writeLines(as.character(tic.log(format = TRUE)), con = log_con)
# Final message
message("End of Code: ", Sys.time())
# Close log connections
sink(type = "message")
sink()
close(log_con)