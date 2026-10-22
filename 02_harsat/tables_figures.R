# Step 2c: tables and figures from the HARSAT assessments ----
#
# Uses the assessments from step 2b (after convergence fixes). Run from run.R,
# which loads the settings (cfg) and functions. Like step 2b, it can be run
# for some groups only by setting `harsat_groups`.
#
# Output in output/<programme>_<year>/harsat/:
#   summaries/<group>.csv      HARSAT summary table per group
#   biota_summary.csv          all groups assessed so far
#   figs/                      time series plots and mean/trend maps (PDF)
#   tables/                    <substance>_<species group>_table.csv
#   contents_for_appendix.csv  species and substances in the report appendix

load_harsat()
groups <- if (exists("harsat_groups")) harsat_groups else names(cfg$harsat$groups)
groups <- groups[file.exists(vapply(groups, assessment_file, "", cfg = cfg))]

lookups <- report_names(cfg)
summary <- write_harsat_summaries(cfg, groups)

duplicate_files <- plot_timeseries(cfg, groups, lookups)
if (length(duplicate_files) > 0) {
  warning("Time series plots overwritten (same file name for two series): ",
          paste(duplicate_files, collapse = ", "), call. = FALSE)
}

rows <- summary_table_rows(summary, lookups, cfg$tables_figures$station_order)
write_summary_tables(cfg, rows)
plot_maps(cfg, rows, lookups)

contents <- appendix_contents(summary, lookups)
readr::write_csv(contents$contents, file.path(harsat_dir(cfg), "contents_for_appendix.csv"))
if (length(contents$missing) > 0) {
  warning("Assessed but not in config/lookups/determinands.csv (left out of the appendix): ",
          paste(contents$missing, collapse = ", "), call. = FALSE)
}

message("Step 2c done: ", paste(groups, collapse = ", "), ". ",
        nrow(summary), " series in biota_summary.csv, ",
        nrow(contents$contents), " species/substance sections for the appendix")
