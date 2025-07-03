#***********************************************************************************************************
#  
# Project: Land cover + Wetlands
# Description: Rasterize WIs 
# Date: 03 July 2025
# Author: Érika Garcez da Rocha
#
#**********************************************************************************************************************************
#**********************************************************************************************************************************
rm(list=ls())

# Load packages ####
# Packages list 
pkgs <- c("sf", "tictoc")

# Load all packages and suppress messages
invisible(lapply(pkgs, function(pkg) suppressMessages(library(pkg, character.only = TRUE))))

# Log ####
# Create log file connection #
log_path <- "./logs/rasterize_WIs_log.txt"
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
# Read Wis merged ####
tic("Read WIs")
wi_vect <- terra::vect("./output/WIs_merged.gpkg")
toc()
gc()
# Rasterize vector of WIs #####
tic("Rasterize and Save WIs")
wi_raster <- terra::rasterize(wi_vect, r, field = "reclass", touches = TRUE,
                              filename = "./output/wetlands_raster.tif",
                              overwrite = TRUE, gdal = c("COMPRESS=LZW"))
crs_w <- terra::crs(wi_raster)
rm(wi_vect)
toc()
gc()
# Compare CRS of WIs raster and NALCMS raster ####
message("All CRS for rasters are identical:\n",identical(crs_r,crs_w))
# Log ####
# Save tic log output
writeLines(as.character(tic.log(format = TRUE)), con = log_con)
# Final message
message("End of Code: ", Sys.time())
# Close log connections
sink(type = "message")
sink()
close(log_con)


