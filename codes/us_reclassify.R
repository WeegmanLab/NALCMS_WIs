#***********************************************************************************************************
#  
# Project: Wetlands Layers
# Description: Merge and Summarize US NWI
# Date: 29 May 2025
# Author: Érika Garcez da Rocha
#
#**********************************************************************************************************************************
#**********************************************************************************************************************************

rm(list=ls())
options(slurmR.verbose = TRUE)
options(clusterEvalQ.verbose = TRUE)
options(clusterEvalQ.verbose = TRUE)
# Load packages ####
# Packages list 
pkgs <- c("sf", "fs", "dplyr", "foreach", "doParallel", 
          "readr", "data.table", "tictoc","janitor")

# Load all packages and suppress messages
invisible(lapply(pkgs, function(pkg) suppressMessages(library(pkg, character.only = TRUE))))
# Log ####
# Create log file connection #
log_path <- "./logs/us_reclassify_log.txt"
log_con <- file(log_path, open = "wt")
sink(log_con, split = TRUE)       # Redirect output to both console and file
sink(log_con, type = "message")   # Redirect messages to file

tic.clearlog()
tic.log(format = TRUE)  # This makes `tic()`/`toc()` log messages printable
message("Starting script: ", Sys.time())
# Read merged layer ####
tic("Read USNWI merged")
us_sf <- sf::st_read("./output/us_wetlands_merged.gpkg", quiet=TRUE) 
toc()
# Reclassify layer ####
tic("Reclassify layer")
reclassified <- us_sf %>%
  mutate(reclass = case_when(
    # Marine
    grepl("^M[12]RF", ATTRIBUTE) ~ NA_real_, # remove reef
    grepl("^M1UB", ATTRIBUTE) ~ 18, #WATER #rock bottom, unconsolidated bottom, aquatic bed
    grepl("^M1RB|^M1UB|^M1AB", ATTRIBUTE) ~ 25, #osw #rock bottom, unconsolidated bottom, aquatic bed
    grepl("^M2AB|^M2US|^M2RS", ATTRIBUTE) ~ 25, #osw #aquatic bed, unconsolidated shore, rocky shore
    # Estuarine
    grepl("^E1UB", ATTRIBUTE) ~ 18, #WATER #rock bottom, unconsolidated bottom, aquatic bed
    grepl("^E[12]RF", ATTRIBUTE) ~ NA_real_, # remove reef
    grepl("^E1RB|^E1UB|^E1AB", ATTRIBUTE) ~ 25, #osw #rock bottom, unconsolidated bottom, aquatic bed
    grepl("^E2US|^E2AB|^E2SB|^E2RS", ATTRIBUTE) ~ 25, #osw #unconsolidated shore, aquatic bed, streambed, rocky shore
    grepl("^E2EM", ATTRIBUTE) ~ 24, #marsh #emergent
    grepl("^E2SS|^E2FO", ATTRIBUTE) ~ 23, #swamp #scrub-shrub, forested
    # Riverine
    # Subsystem R5 - Unknown
    grepl("^R[1235]UB", ATTRIBUTE) ~ 18, #WATER #rock bottom, unconsolidated bottom, aquatic bed
    grepl("^R4", ATTRIBUTE) ~ 25, #osw 
    grepl("^R[1235]RS|^R[1235]RB|^R[1235]US|^R[1235]SB|^R[1235]AB", ATTRIBUTE) ~ 25, #osw #rocky shore, rock bottom, unconsolidated shore, streambed, aquatic bed, unconsolidated bottom
    grepl("^R[1235]EM", ATTRIBUTE) ~ 24, #marsh #emergent
    # Lacustrine
    grepl("^L1UB", ATTRIBUTE) ~ 18, #WATER #rock bottom, unconsolidated bottom, aquatic bed
    grepl("^L[12]RB|^L[12]RS|^L[12]UB|^L[12]AB|^L[12]US", ATTRIBUTE) ~ 25, #osw #rock bottom, rocky shore, unconsolidated bottom, aquatic bed, unconsolidade shore
    grepl("^L2EM", ATTRIBUTE) ~ 24, #marsh #emergent
    # Palustrine
    grepl("^(PSS3|PFO2)[^/]*[DB]([^/]*)?(\\/|$)", ATTRIBUTE) ~ 20, #bog 
    grepl("^P[^/]*g(\\/|$)", ATTRIBUTE) ~ 22, #peatland #organic soils 
    grepl("^PSS|^PFO", ATTRIBUTE) ~ 23, #swamp #scrub-shrub and forested 
    grepl("^PRB|^PUB|^PAB|^PUS", ATTRIBUTE) ~ 25, #osw #rock bottom, unconsolidated bottom, aquatic bed, unconsolidated shore
    grepl("^PML", ATTRIBUTE) ~ 22, #peatland #moss-lichen
    grepl("^PEM", ATTRIBUTE) ~ 24, #marsh #emergent
    # These are not clear in the classification, but I checked and it is all lakes. 
    ATTRIBUTE %in% c("L") ~ 18, #WATER #Lacustrine no specification 
    ATTRIBUTE %in% c("Lx") ~ 25, #osw #Lacustrine diked/impounded
    ATTRIBUTE %in% c("Lh") ~ 24, #marsh #Lacustrine excavated
    ATTRIBUTE %in% c("P", "Pf") ~ 24, #marsh, #Palustrine no specification and farmed
    TRUE ~ NA #99 #value to debug latter - just four locations with 99. Not sure why. 
  ))  %>%
  mutate(original=ATTRIBUTE) %>%
  clean_names() %>%
  dplyr::select(original,reclass,shape_length,shape_area,geom)
toc()
# Save reclassified layer ####
tic("Save reclassified layer")
if (!is.null(reclassified)) st_write(reclassified, 
                                     file.path("output", "us_wetlands_merged_reclassified.gpkg"),
                                     append = FALSE)
toc()
# # Filter not reclassified features ####
# tic("get wrong reclassified layer")
# wrong <- reclassified %>%
#   filter(!reclass %in% c("marsh","swamp","peatland","osw","deepwater"))
# if (!is.null(wrong)) st_write(wrong, file.path("output", "us_wrong.gpkg"))
# toc()
# Save summary of reclassification ####
tic("Summarize Reclassified Layer")
sum_r <- reclassified %>%
  st_drop_geometry() %>%
  group_by(reclass) %>%
  summarise(n = n(), .groups = "drop") %>%
  mutate(proportion = n / sum(n))
toc()
# Save summary ####
tic("Save summary")
write.csv(sum_r,"./output/us_merged_reclassified_sum.csv",row.names = FALSE)
toc()
gc()
# Log ####
# Save tic log output
writeLines(as.character(tic.log(format = TRUE)), con = log_con)
#terra::crs(reclassified)

# Final message
message("End of Code: ", Sys.time())

# Close log connections
sink(type = "message")
sink()
close(log_con)
