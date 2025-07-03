#***********************************************************************************************************
#  
# Project: Wetlands Layers
# Description: Merge and Summarize CNWI
# Date: 29 May 2025
# Author: Érika Garcez da Rocha
#
#**********************************************************************************************************************************
#**********************************************************************************************************************************

rm(list=ls())
options(slurmR.verbose = TRUE)
options(clusterEvalQ.verbose = TRUE)
# Load packages ####
# Packages list 
pkgs <- c("sf", "fs", "dplyr", "foreach", "doParallel", 
          "readr", "data.table", "tictoc", "janitor")

# Load all packages and suppress messages
invisible(lapply(pkgs, function(pkg) suppressMessages(library(pkg, character.only = TRUE))))

# Log ####
# Create log file connection #
log_path <- "./logs/can_merge_log.txt"
log_con <- file(log_path, open = "wt")
sink(log_con, split = TRUE)       # Redirect output to both console and file
sink(log_con, type = "message")   # Redirect messages to file

tic.clearlog()
tic.log(format = TRUE)  # This makes `tic()`/`toc()` log messages printable
message("Starting script: ", Sys.time())

# Get CRS from raster NALCMS ####
tic("Read NALCMS")
r <- terra::rast("./NA_NALCMS_landcover_2020_30m/data/NA_NALCMS_landcover_2020_30m.tif")
crs_r <- terra::crs(r)
rm(r)
toc()
# Set directories ####
zip_dir <- "./can_zipped"#/east"
temp_unzip_dir <- "./unzipped"

# List zip files ####
zip_files <- dir_ls(zip_dir, regexp = "\\.zip$")

# List to storage data ####
wetlands_list <- list()

# Process each zip file ####
process_zip <- function(zip_file) {
  zip_name <- path_ext_remove(path_file(zip_file))
  write(paste0("\nCore:",Sys.getpid()," - Start Processing: ", zip_name), file = "./logs/can_merge_steps.txt", append = TRUE)
  
  # Diretorios temporarios e unzip file 
  temp_unzip_dir_local <- file.path(tempdir(), paste0("cnwi_", Sys.getpid(), "_", zip_name))
  dir.create(temp_unzip_dir_local, showWarnings = FALSE)
  unzip(zip_file, exdir = temp_unzip_dir_local)
  
  # Localiza o geodatabase (.gdb) - assume que só existe um
  gdb_path <- dir_ls(temp_unzip_dir_local, type = "directory", regexp = "\\.gdb$")[1]
  message("Found GDB: ", gdb_path)
  
  # List layers
  gdb_layers <- st_layers(gdb_path)$name
  #wetlands_layer <- gdb_layers[grepl("(Wetlands|Riparian)$", gdb_layers)]
  wetlands_layer <- gdb_layers
  wetlands_sf <- NULL
  
  wetlands_sf <- bind_rows(lapply(wetlands_layer, function(layer) {
    message("  Reading Wetlands layer: ", layer)
    x <- tryCatch(st_read(gdb_path, layer = layer, quiet = TRUE), error = function(e) NULL)
    if (!is.null(x)) x <- st_make_valid(x) #check geometry
    write(paste0("\nCore:",Sys.getpid()," - Start Reprojecting: ", zip_name), file = "./logs/can_merge_steps.txt", append = TRUE)
    x <- st_transform(x, crs_r)  # reproject
    write(paste0("\nCore:",Sys.getpid()," - End Reprojecting: ", zip_name), file = "./logs/can_merge_steps.txt", append = TRUE)
    x
  }))
  
  gc()
  #clean temporary directory
  dir_delete(temp_unzip_dir_local)
  write(paste0("\nCore:",Sys.getpid()," - End Processing: ", zip_name), file = "./logs/can_merge_steps.txt", append = TRUE)
  # Retorna lista nomeada
  return(list(name = zip_name, wetlands = wetlands_sf))
}

# Start cluster
num_cores <- as.integer(Sys.getenv("SLURM_CPUS_PER_TASK", unset = 1))
message("Cores detected: ", num_cores)
clt <- parallel::makePSOCKcluster(num_cores)
doParallel::registerDoParallel(clt)

tic("Process all zip files")
wetlands_list <- foreach(zip = zip_files, .packages = c("sf","fs","dplyr")) %dopar% {
  message(">> Starting: ", zip, "\n")
  flush.console()
  process_zip(zip)
}
toc(log=TRUE)

stopCluster(clt)
# rename list and merge all files ####
tic("Rename list and merge zip files")
wetlands_list <- setNames(
  lapply(wetlands_list, `[[`, "wetlands"), 
  sapply(wetlands_list, `[[`, "name")
)

# merge all files 
wetlands_merged <- if (any(!sapply(wetlands_list, is.null))) {
  bind_rows(Filter(Negate(is.null), wetlands_list))
} else {
  NULL
}
toc(log=TRUE) 
# Save merged layer ####
tic("Save merged layer")
if (!is.null(wetlands_merged)) st_write(wetlands_merged, 
                                        file.path("output", "can_wetlands_merged.gpkg"),
                                        append=FALSE)
toc(log=TRUE)
# Summarize Attributes ####
tic("Summarize attributes")
sum <- wetlands_merged %>%
  st_drop_geometry() %>%
  group_by(CNWI_CLASS) %>%
  summarise(n = n(), .groups = "drop") %>%
  mutate(proportion = n / sum(n))
toc(log=TRUE)
# Save summary ####
tic("Save summary")
write.csv(sum,"./output/can_merged_sum.csv",row.names=FALSE)
toc(log=TRUE)
# Log ####
# Save tic log output
writeLines(as.character(tic.log(format = TRUE)), con = log_con)
# Final message
message("End of Code: ", Sys.time())
# Close log connections
sink(type = "message")
sink()
close(log_con)
