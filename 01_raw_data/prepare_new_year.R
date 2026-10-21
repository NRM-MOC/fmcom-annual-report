# Step 1: new year's raw data -> fmcom format + QC ----
#
# Reads the lab files and esbase biological data listed in
# config/<programme>.yml, converts them to fmcom format and runs the step 1
# QC checks. Run from run.R, which loads the settings (cfg) and functions.
#
# Output in output/<programme>_<year>/:
#   new_year_data.rds / .csv  the new year's data in fmcom format (frozen
#                             input for steps 2 and 3)
#   qc_step1.csv              QC checks; review before continuing to step 2
#   run_info_step1.yml        code, data and package versions used

lab <- read_lab_files(cfg)
bio <- read_esbase(cfg)
master <- load_master_tables()

new_year <- to_fmcom_format(lab$data, bio, master, year = cfg$year)
qc <- qc_step1(cfg, lab, bio, new_year, master)

# Winter conditions affect contaminant concentrations; winter samples are
# listed in the QC output but left out of the data
new_year <- dplyr::filter(new_year, !season %in% "Winter")

saveRDS(new_year, file.path(output_dir(cfg), "new_year_data.rds"))
readr::write_csv(new_year, file.path(output_dir(cfg), "new_year_data.csv"), na = "")
readr::write_csv(qc, file.path(output_dir(cfg), "qc_step1.csv"), na = "")
write_run_info(cfg, "step1", extra = list(
  lab_files = vapply(cfg$raw_data$lab_files, `[[`, "", "file"),
  esbase_file = cfg$raw_data$esbase_file,
  fmcom_master_tables = master$ref
))

message("Step 1 done: ", nrow(new_year), " rows, ",
        dplyr::n_distinct(new_year$sample_ID), " lab samples. QC: ",
        sum(qc$n > 0), " of ", nrow(qc), " checks found something; see qc_step1.csv")
