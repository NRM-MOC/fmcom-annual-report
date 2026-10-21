# Step 2b: run HARSAT ----
#
# Runs the HARSAT assessment for each group, then tries to fix time series
# that did not converge (config/harsat/convergence_fixes.yml). Run from
# run.R, which loads the settings (cfg) and functions. A full run takes
# several hours; to run only some groups, set `harsat_groups` first, e.g.
# harsat_groups <- c("PAH").
#
# Output in output/<programme>_<year>/harsat/:
#   assessments/<group>_unfixed.rds  assessment as run
#   assessments/<group>.rds          after convergence fixes (used from here on)
#   oddities/<group>/                HARSAT's data checks
#   convergence_log.csv              non-converged series, what was tried, result
#   run_info_step2.yml               code, data and package versions used

harsat_info <- load_harsat()
groups <- if (exists("harsat_groups")) harsat_groups else names(cfg$harsat$groups)

convergence <- purrr::map(groups, function(group) run_harsat_group(cfg, group)) |>
  dplyr::bind_rows()

# Keep earlier results for groups not run this time
log_file <- file.path(harsat_dir(cfg), "convergence_log.csv")
if (file.exists(log_file)) {
  earlier <- readr::read_csv(log_file, col_types = readr::cols(.default = "c"))
  convergence <- dplyr::bind_rows(dplyr::filter(earlier, !group %in% groups), convergence)
}
readr::write_csv(convergence, log_file, na = "")
write_run_info(cfg, "step2", harsat = harsat_info, extra = list(groups_run = groups))

unresolved <- dplyr::filter(convergence, group %in% groups, is.na(resolved_with))
message("Step 2b done: ", paste(groups, collapse = ", "), ". Not converged: ",
        sum(convergence$group %in% groups), ", fixed: ",
        sum(convergence$group %in% groups & !is.na(convergence$resolved_with)),
        ", unresolved: ", nrow(unresolved), " (see convergence_log.csv)")
