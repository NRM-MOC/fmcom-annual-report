# Annual contaminant report pipeline ----
#
# Run one step at a time, top to bottom. The pipeline is NOT one continuous
# run: QC happens after step 1 and again after step 3, when the finished
# report is reviewed. Problems found in the report go back to the labs; after
# correction, all three steps are re-run.
#
# Yearly cycle: before starting, fmcom must already contain last year's data
# (downloaded from SGU). This pipeline temporarily adds the new year's data
# from the lab files. Nothing here goes to SGU; the QC'd new-year data is
# submitted to SGU afterwards through a separate pipeline.
#
# Settings live in config/<programme>.yml. Local settings (data location,
# HARSAT development copy) live in .Renviron; see .Renviron.example.

## Setup ----
programme <- "marine"   # "marine" or "freshwater"

for (f in list.files(here::here("R"), pattern = "\\.R$", full.names = TRUE)) source(f)
cfg <- load_config(programme)
message("Running ", cfg$run_name, " (data through ", cfg$year, ")")

## Step 1: new year's raw data -> fmcom format + QC ----
source(here::here("01_raw_data", "prepare_new_year.R"))

## ---- QC CHECKPOINT 1: new year's data ----
# Review the QC output, contact labs if needed, and add any corrections to
# config/corrections/. Re-run step 1 until the new year's data is accepted,
# then continue.

## Step 2: HARSAT assessment, tables and figures ----
source(here::here("02_harsat", "prepare_harsat_input.R"))

# A full HARSAT run takes several hours; to run only some groups:
# harsat_groups <- c("PAH")
source(here::here("02_harsat", "run_harsat.R"))
source(here::here("02_harsat", "tables_figures.R"))

## Step 3: report (appendix PDF) ----
# Edit the year-specific text first (config: report: text_file)
source(here::here("03_report", "generate_appendix.R"))

## ---- QC CHECKPOINT 2: the finished report ----
# Look through the report for oddities (trends, outliers, missing series).
# If something is wrong in the data, contact the lab, add the correction to
# config/corrections/, and re-run all three steps from step 1.
