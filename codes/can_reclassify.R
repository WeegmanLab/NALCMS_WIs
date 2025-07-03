#***********************************************************************************************************
#  
# Project: Land cover + Wetlands
# Description: Reclassify CNWI
# Date: 3 July 2025
# Author: Érika Garcez da Rocha
#
#**********************************************************************************************************************************
#**********************************************************************************************************************************

rm(list=ls())
options(slurmR.verbose = TRUE)
options(clusterEvalQ.verbose = TRUE)
# Load packages ####
# Packages list 
pkgs <- c("sf", "fs", "dplyr",
          "readr", "data.table", "tictoc", "janitor")

# Load all packages and suppress messages
invisible(lapply(pkgs, function(pkg) suppressMessages(library(pkg, character.only = TRUE))))

# Log ####
# Create log file connection #
log_path <- "./logs/can_reclassify_log.txt"
log_con <- file(log_path, open = "wt")
sink(log_con, split = TRUE)       # Redirect output to both console and file
sink(log_con, type = "message")   # Redirect messages to file

tic.clearlog()
tic.log(format = TRUE)  # This makes `tic()`/`toc()` log messages printable
message("Starting script: ", Sys.time())

# Read merged layer ####
tic("Read CNWI merged")
can_sf <- sf::st_read("./output/can_wetlands_merged.gpkg", quiet=TRUE) 
toc()
# Reclassify layer ####
tic("Reclassify layer")
reclassified <- can_sf %>%
  mutate(reclass = case_when(
    CNWI_CLASS %in% c(1) ~ 20, #bog
    CNWI_CLASS %in% c(2,6,7) ~ 21, #fen
    CNWI_CLASS %in% c(3,8,9) ~ 23, #swamp
    CNWI_CLASS %in% c(4,10,11) ~ 24, #marsh
    CNWI_CLASS %in% c(5,12,13) ~ 25, #osw 
    CNWI_CLASS %in% c(14) ~ 22, #peatland
    CNWI_CLASS %in% c(15) ~ 14, #mixed # 14 is wetlands class in NALCMS
    CNWI_CLASS %in% c(16) ~ 14, #unclassified  # 14 is wetlands class in NALCMS
    TRUE ~ CNWI_CLASS  # Convert to character to match other outputs
  )) %>%
  mutate(original=CNWI_CLASS) %>%
  clean_names() %>%
  dplyr::select(original,reclass,shape_length,shape_area,geom)
toc(log=TRUE)
# Save reclassified layer ####
tic("Save reclassified layer")
if (!is.null(reclassified)) st_write(reclassified, file.path("output", "can_wetlands_merged_reclassified.gpkg"))
toc(log=TRUE)
# Save summary of reclassification ####
tic("Summarize Reclassified Layer")
sum_r <- reclassified %>%
  st_drop_geometry() %>%
  group_by(reclass) %>%
  summarise(n = n(), .groups = "drop") %>%
  mutate(proportion = n / sum(n))
toc(log=TRUE)
# Save summary ####
tic("Save summary")
write.csv(sum_r,"./output/can_merged_reclassified_sum.csv",row.names=FALSE)
toc(log=TRUE)
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
