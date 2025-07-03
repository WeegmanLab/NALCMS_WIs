#***********************************************************************************************************
#  
# Project: Land cover + Wetlands
# Description: Update NALCMS land cover raster with WIs classes
# Date: 03 July 2025
# Author: Érika Garcez da Rocha
#
#**********************************************************************************************************************************
#**********************************************************************************************************************************

rm(list=ls())
# Load packages ####
# Packages list 
pkgs <- c("tictoc" , "dplyr")
# Load all packages and suppress messages
invisible(lapply(pkgs, function(pkg) suppressMessages(library(pkg, character.only = TRUE))))

# Log ####
# Create log file connection #
log_path <- "./logs/update_raster_log.txt"
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
# Read raster WIs ####
tic("Read raster WIs")
wi <- terra::rast("./output/wetlands_raster.tif") 
crs_wi <- terra::crs(wi)
toc()
# Check CRS ####
cat("All raster CRS is identical:", identical(crs_r,crs_wi))

# Update raster ####
tic("Update raster")
r_new <- terra::ifel(
  r == 0, #if r == 0
  r,      #keep r values, which is 0.    
  terra::ifel(
    is.na(wi) | wi == 0, #if wi is NA or 0, 
    r,                   #keep r values  
    wi                   #otherwise, change to wi values. 
    )
  )
#replace all wi in r, when both is not NA or 0 in NALCMS. 
#wi has marine areas, but that is 0 in nalcms, then it will not be replaced. 
toc()
# Save raster ####
tic("Save updated raster")
terra::writeRaster(r_new, "./output/nalcms_updated.tif",
                   overwrite = TRUE, gdal = c("COMPRESS=LZW"))
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


