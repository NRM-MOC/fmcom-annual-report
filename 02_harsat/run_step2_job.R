# Step 2 as an RStudio background job ----
#
# Runs steps 2a-2c (HARSAT input, HARSAT, tables and figures) in a separate R
# session, so RStudio stays free while HARSAT runs. Start it from the console
# (see the README, "Running HARSAT as a background job"):
#
#   programme <- "marine"
#   rstudioapi::jobRunScript(here::here("02_harsat", "run_step2_job.R"),
#                            workingDir = here::here(), importEnv = TRUE)
#
# importEnv = TRUE gives the job the objects in your session: `programme`,
# and `harsat_groups` if it is set (to run only some groups).
# Step 3 (the report) is left out, so the convergence log can be checked
# first.

if (!exists("programme")) {
  stop('Set the programme first, e.g. programme <- "marine", and start the job with importEnv = TRUE.',
       call. = FALSE)
}

for (f in list.files(here::here("R"), pattern = "\\.R$", full.names = TRUE)) source(f)
cfg <- load_config(programme)
message("Running step 2 for ", cfg$run_name, " (data through ", cfg$year, ")")

source(here::here("02_harsat", "prepare_harsat_input.R"))
source(here::here("02_harsat", "run_harsat.R"))
source(here::here("02_harsat", "tables_figures.R"))
