#***********************************************************************************************************
#  
# Project: Land cover + Wetlands
# Description: Merge Wetland Inventory Reclassified Layers 
# Date: 3 July 2025
# Author: Érika Garcez da Rocha
#
#**********************************************************************************************************************************
#**********************************************************************************************************************************

rm(list=ls())
# Load packages ####
# Packages list 
pkgs <- c("sf", "tictoc","dplyr")

# Load all packages and suppress messages
invisible(lapply(pkgs, function(pkg) suppressMessages(library(pkg, character.only = TRUE))))

# Log ####
# Create log file connection #
log_path <- "./logs/mergeWIs_log.txt"
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
# Read can and us WIs vectors ####
tic("Read CNWI")
can_sf <- sf::st_read("./output/can_wetlands_merged_reclassified.gpkg", quiet=TRUE) %>%
  dplyr::filter(!is.na(reclass)) %>%
  mutate(original = as.character(original))
crs_can <- st_crs(can_sf)
toc()

tic("Read USNWI")
us_sf <- sf::st_read("./output/us_wetlands_merged_reclassified.gpkg", quiet=TRUE) %>%
  dplyr::filter(!is.na(reclass)) %>%
  mutate(original = as.character(original))
crs_us <- st_crs(us_sf)
toc()

# Check colnames and CRS ####
write(paste0("Raster CRS:",crs_r), file = "./logs/CRS_merge_WIs.txt", append = TRUE)
write(paste0("CAN CRS:",crs_can), file = "./logs/CRS_merge_WIs.txt", append = TRUE)
write(paste0("US CRS:",crs_us), file = "./logs/CRS_merge_WIs.txt", append = TRUE)
message("same colnames:",all.equal(colnames(can_sf),colnames(us_sf)))
message("All CRS for WIS are identical:\n",identical(crs_us$wkt,crs_can$wkt))
# Merge WIs ####
tic("Merge WIs")
merged_sf <- bind_rows(can_sf, us_sf)
toc()
# Clean environment ####
rm(can_sf, us_sf)
gc()
# Check geometries ####
tic("Check geometries")
invalid <- !st_is_valid(merged_sf)
cat(if (any(invalid, na.rm = TRUE)) "Invalid Geometries!\n" else "Correct Geometries!\n")
if (any(invalid, na.rm = TRUE)) {
  cat("Fixing Geometries!\n")
  merged_sf <- st_make_valid(merged_sf)
  invalid2 <- !st_is_valid(merged_sf)
  cat(if (any(invalid2, na.rm = TRUE)) "Invalid Geometries!\n" else "Correct Geometries!\n")
} 
toc()
# Save merged layer ####
tic("Save merged layer")
if (!is.null(merged_sf)) st_write(merged_sf,
                                  file.path("output", "WIs_merged.gpkg"),
                                  append = FALSE)
toc(log=TRUE)
# Save summary of reclassification ####
tic("Summarize WIs_merged")
sum_r <- merged_sf %>%
  st_drop_geometry() %>%
  group_by(reclass) %>%
  summarise(n = n(), .groups = "drop") %>%
  mutate(proportion = n / sum(n))
toc()
# Save summary ####
tic("Save summary")
write.csv(sum_r, "./output/WIs_merged_sum.csv", row.names = FALSE)
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
