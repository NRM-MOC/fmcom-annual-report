# Run record ----
#
# Writes run_info_<step>.yml to the output folder: which code, data and
# package versions produced the output. Needed to reproduce a published report.

write_run_info <- function(cfg, step, harsat = NULL) {
  commit <- tryCatch(
    system2("git", c("-C", shQuote(here::here()), "rev-parse", "--short", "HEAD"), stdout = TRUE),
    error = function(e) NA_character_, warning = function(w) NA_character_
  )
  dirty <- tryCatch(
    length(system2("git", c("-C", shQuote(here::here()), "status", "--porcelain"), stdout = TRUE)) > 0,
    error = function(e) NA, warning = function(w) NA
  )
  info <- list(
    step        = step,
    programme   = cfg$programme,
    year        = cfg$year,
    run_at      = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
    code_commit = commit,
    uncommitted_changes = dirty,
    fmcom       = fmcom_version(),
    harsat      = harsat,
    R_version   = R.version.string
  )
  path <- file.path(output_dir(cfg), paste0("run_info_", step, ".yml"))
  yaml::write_yaml(info, path)
  invisible(path)
}
