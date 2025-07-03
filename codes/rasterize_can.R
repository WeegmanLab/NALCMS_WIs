#***********************************************************************************************************
#  
# Project: Land cover + Wetlands
# Description: Rasterize CAN WI 
# Date: 3 July 2025
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
tic("Rasterize and Save")
can_raster <- terra::rasterize(can_vect, r, field = "CNWI_CLASS", touches=TRUE,
                              filename = "./output/can_wetlands_raster.tif",
                              overwrite = TRUE, gdal = c("COMPRESS=LZW"))
rm(can_vect)
toc()
gc()
# Log ####
# Save tic log output
writeLines(as.character(tic.log(format = TRUE)), con = log_con)
# Final message
message("End of Code: ", Sys.time())
# Close log connections
sink(type = "message")
sink()
close(log_con)
