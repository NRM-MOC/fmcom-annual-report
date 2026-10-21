# Step 2a: fmcom + new year -> HARSAT input files ----
#
# Combines fmcom with the new year's data from step 1 and writes one HARSAT
# input file per group in config/<programme>.yml, plus the stations file.
# Run from run.R, which loads the settings (cfg) and functions.
#
# Output in output/<programme>_<year>/harsat/data/:
#   NRM_<group>.csv   HARSAT input, one per group
#   stations.csv      HARSAT stations (HARSAT reads it from the same folder)

data <- load_fmcom_with_new_year(cfg)
rows <- write_harsat_input(cfg, data)

message("Step 2a done: HARSAT input written for ",
        paste0(names(rows), " (", rows, " rows)", collapse = ", "))
