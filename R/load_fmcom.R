# Historical data (fmcom) ----
#
# The only place the pipeline reads the historical data. When the data moves
# to Specify, only this function should need to change.

load_fmcom <- function(cfg) {
  fmcom::fmcom |>
    dplyr::filter(water_type == cfg$water_type)
}

## fmcom plus the new year's data from step 1 ----
# The temporary combined dataset, e.g. for use during the year. The new year
# is marked source = "new_year".
load_fmcom_with_new_year <- function(cfg) {
  new_year <- readRDS(file.path(output_dir(cfg, create = FALSE), "new_year_data.rds"))
  load_fmcom(cfg) |>
    dplyr::mutate(dplyr::across(dplyr::where(is.factor), as.character),
                  source = "fmcom") |>
    dplyr::bind_rows(new_year)
}

## Version of fmcom in use, for the run record ----
fmcom_version <- function() {
  desc <- utils::packageDescription("fmcom")
  list(
    version = desc$Version,
    commit  = if (is.null(desc$RemoteSha)) "not installed from GitHub" else desc$RemoteSha
  )
}
