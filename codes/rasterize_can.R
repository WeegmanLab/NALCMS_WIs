#***********************************************************************************************************
#  
# Project: Wetlands Layers
# Description: Rasterize WIs 
# Date: 29 May 2025
# Author: Érika Garcez da Rocha
#
#**********************************************************************************************************************************
#**********************************************************************************************************************************
rm(list=ls())
# Load packages ####
# Packages list 
pkgs <- c("sf", "tictoc" , "dplyr", "stringr")

# Load all packages and suppress messages
invisible(lapply(pkgs, function(pkg) suppressMessages(library(pkg, character.only = TRUE))))

# Log ####
# Create log file connection #
log_path <- "./logs/rasterize_can_log.txt"
log_con <- file(log_path, open = "wt")
sink(log_con, split = TRUE)       # Redirect output to both console and file
sink(log_con, type = "message")   # Redirect messages to file

tic.clearlog()
tic.log(format = TRUE)  # This makes `tic()`/`toc()` log messages printable
message("Starting script: ", Sys.time())
# Read raster NALCMS ####
tic("Read NALCMS")
r <- terra::rast("./NA_NALCMS_landcover_2020_30m/data/NA_NALCMS_landcover_2020_30m.tif")
crs_r <- terra::crs(r)
toc()
# Read can WIs vector ####
tic("Read CNWI")
can_sf <- terra::vect("./output/can_wetlands_merged.gpkg") 
toc()
# Rasterize vector of WIs #####
tic("Rasterize Can")
can_raster <- terra::rasterize(can_vect, r, field="CNWI_CLASS", touches=TRUE)
rm(can_vect)
toc()
gc()
# Save raster ####
tic("Save final rasters")
terra::writeRaster(can_raster, "./output/can_wetlands_raster.tif", overwrite=TRUE,
                   gdal = c("COMPRESS=LZW"))
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
