# Configuration and paths ----
#
# All paths in the pipeline are built from here, so the data location can be
# switched (local test data vs shared drive) by setting FMCOM_DATA_DIR in
# .Renviron, without touching any script.

## Read programme settings ----
load_config <- function(programme = c("marine", "freshwater")) {
  programme <- match.arg(programme)
  cfg <- yaml::read_yaml(here::here("config", paste0(programme, ".yml")))
  cfg$run_name <- paste(cfg$programme, cfg$year, sep = "_")   # e.g. "marine_2025"
  cfg
}

## Data folder (gitignored) ----
data_dir <- function(...) {
  root <- Sys.getenv("FMCOM_DATA_DIR", unset = here::here("data"))
  file.path(root, ...)
}

## Output folder for one programme and year, e.g. output/marine_2025/ ----
output_dir <- function(cfg, ..., create = TRUE) {
  path <- here::here("output", cfg$run_name, ...)
  if (create && !dir.exists(path)) dir.create(path, recursive = TRUE)
  path
}
