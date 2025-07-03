#***********************************************************************************************************
#  
# Project: Wetlands Layers
# Description: Merge US NWI
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
log_path <- "./logs/us_merge_log.txt"
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
zip_dir <- "./us_zipped"#/east"
temp_unzip_dir <- "./unzipped"

# List zip files ####
zip_files <- dir_ls(zip_dir, regexp = "\\.zip$")

# List to storage data ####
wetlands_list <- list()

# Process each zip files ####
process_zip <- function(zip_file) {
  zip_name <- path_ext_remove(path_file(zip_file)) #get file name
  write(paste0("\nCore:",Sys.getpid()," - Start Processing: ", zip_name), file = "./logs/us_merge_steps.txt", append = TRUE)
  
  #create a temporary directory
  temp_unzip_dir_local <- file.path(tempdir(), paste0("usnwi_", Sys.getpid(), "_", zip_name)) 
  dir.create(temp_unzip_dir_local, showWarnings = FALSE)
  
  #unzip file into temporary directory
  unzip(zip_file, exdir = temp_unzip_dir_local)
  
  # Get geodatabase (.gdb) 
  gdb_path <- dir_ls(temp_unzip_dir_local, type = "directory", regexp = "\\.gdb$")[1]

  # List layers and get just Wetlands
  gdb_layers <- st_layers(gdb_path)$name
  #wetlands_layer <- gdb_layers[grepl("(Wetlands|Riparian)$", gdb_layers)]
  wetlands_layer <- gdb_layers[grepl("Wetlands$", gdb_layers)]
  wetlands_sf <- NULL
  
  wetlands_sf <- bind_rows(lapply(wetlands_layer, function(layer) {
    # read layers
    x <- tryCatch({
      st_read(gdb_path, layer = layer, quiet = TRUE, options = c("PROMOTE_TO_MULTI", "OGR_ORGANIZE_POLYGONS=ONLY_CCW"))
    }, error = function(e) {
      write(paste0("Failed to read layer: ", layer, " - ", e$message), file = "./logs/us_merge_log.txt", append = TRUE)
      NULL
    })
    # check geometries and convert to Multipolygon when needed 
    if (any(st_geometry_type(x) == "MULTISURFACE")) {
      write(paste0("\nCore:",Sys.getpid()," - Converting MULTISURFACE para MULTIPOLYGON: ", zip_name), file = "./logs/us_merge_steps.txt", append = TRUE)
      x <- st_cast(x, "MULTIPOLYGON") # Convert to multipolygon when needed 
    }
    # fix geometries
    write(paste0("\nCore:",Sys.getpid()," - Fixing Geometries: ", zip_name), file = "./logs/us_merge_steps.txt", append = TRUE)
    x <- st_make_valid(x)  
    # reproject to same CRS as raster
    write(paste0("\nCore:",Sys.getpid()," - Reprojecting: ", zip_name), file = "./logs/us_merge_steps.txt", append = TRUE)
    x <- st_transform(x, crs_r)  
    #return object 
    x
  }))
  gc()
  
  #clean temporary directory
  dir_delete(temp_unzip_dir_local)
  write(paste0("\nCore:",Sys.getpid()," - End Processing: ", zip_name), file = "./logs/us_merge_steps.txt", append = TRUE)
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
  process_zip(zip)
}
toc()

stopCluster(clt)
# rename list and merge all files ####
tic("Rename list and merge zip files")
wetlands_list <- setNames(
  lapply(wetlands_list, `[[`, "wetlands"), 
  sapply(wetlands_list, `[[`, "name")
)

wetlands_merged <- if (any(!sapply(wetlands_list, is.null))) {
  bind_rows(Filter(Negate(is.null), wetlands_list))
} else {
  NULL
}
toc()

# Save merged layer ####
tic("Save merged layer")
if (!is.null(wetlands_merged)) st_write(wetlands_merged, 
                                        file.path("output", "us_wetlands_merged.gpkg"),
                                        append=FALSE)
toc()
# Summarize Attributes ####
tic("Summarize attributes")
sum <- wetlands_merged %>%
  st_drop_geometry() %>%
  group_by(ATTRIBUTE) %>%
  summarise(n = n(), .groups = "drop") %>%
  mutate(proportion = n / sum(n))
toc()
# Save summary ####
tic("Save summary")
write.csv(sum,"./output/us_merged_sum.csv",row.names = FALSE)
toc()
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
