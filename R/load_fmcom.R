# Historical data (fmcom) ----
#
# The only place the pipeline reads the historical data. When the data moves
# to Specify, only this function should need to change.

load_fmcom <- function(cfg) {
  fmcom::fmcom |>
    dplyr::filter(water_type == cfg$water_type)
}

## Version of fmcom in use, for the run record ----
fmcom_version <- function() {
  desc <- utils::packageDescription("fmcom")
  list(
    version = desc$Version,
    commit  = if (is.null(desc$RemoteSha)) "not installed from GitHub" else desc$RemoteSha
  )
}
