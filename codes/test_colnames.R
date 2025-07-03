rm(list=ls())
# Load packages ####
# Packages list 
pkgs <- c("sf", "tictoc")

# Load all packages and suppress messages
invisible(lapply(pkgs, function(pkg) suppressMessages(library(pkg, character.only = TRUE))))

# Read can WIs vectors ####
tic("Read CNWI")
can_sf  <- sf::st_read("./output/can_wetlands_merged.gpkg", quiet=TRUE)
toc()

colnames(can_sf)

# Read  us WIs vectors ####
tic("Read USNWI")
us_sf  <- sf::st_read("./output/us_wetlands_merged.gpkg", quiet=TRUE)
toc()

colnames(us_sf)