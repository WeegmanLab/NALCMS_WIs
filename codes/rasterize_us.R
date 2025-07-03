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
log_path <- "./logs/rasterize_us_log.txt"
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
# Read us WIs vector ####
tic("Read USNWI")
us_vect <- terra::vect("./output/us_wetlands_merged.gpkg")
toc()

tic("Create lookup table")
us_attrib <- as.data.frame(us_vect) 
us_attrib$ATT <- stringr::str_extract(us_attrib$ATTRIBUTE, "^[A-Z][0-9][A-Z]{2}")
us_attrib$ATT_num <- as.numeric(as.factor(us_attrib$ATT))

# Add ATT_num to SpatVector 
us_vect$ATT_num <- us_attrib$ATT_num

# Table to check attributes 
lookup_table <- us_attrib |>
  dplyr::select(ATT, ATT_num) |>
  dplyr::distinct() |>
  dplyr::arrange(ATT_num)

print(lookup_table)
toc()
# Rasterize vector of WIs #####
tic("Rasterize Can")
us_raster <- terra::rasterize(us_vect, r, field = "ATT_num", touches=TRUE,
                              filename = "./output/tmp_us_raster.tif",
                              overwrite = TRUE, gdal = c("COMPRESS=LZW"))
rm(us_vect,r)
toc()
gc()
# Save raster ####
tic("Save final raster")
terra::writeRaster(us_raster, "./output/us_wetlands_raster.tif", overwrite=TRUE,
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
