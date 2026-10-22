# Step 3: report appendix (PDF) ----
#
# Builds the appendix from step 2's output (contents_for_appendix.csv,
# figures and tables) and renders it to PDF. Run from run.R, which loads the
# settings (cfg) and functions.
#
# Text: 03_report/rmd/header.Rmd (shared) and the programme's text file
# (config: report: text_file), edited each year.
#
# Output in output/<programme>_<year>/report/:
#   appendix_<programme>_<year>.Rmd / .tex / .pdf
#   run_info_step3.yml

contents <- read.csv(file.path(harsat_dir(cfg), "contents_for_appendix.csv"))
report_dir <- output_dir(cfg, "report")

# Settings read by the templates
options(
  appendix.base_path = harsat_dir(cfg),
  appendix.year = cfg$year,
  appendix.recent_trend = as.integer(cfg$harsat$recent_trend),
  appendix.station_order = report_station_order(cfg),
  appendix.thresholds = here::here(cfg$report$thresholds_file),
  # Variables HARSAT models on the original scale (trends in unit per year)
  appendix.normal_vars = file_code(with(report_names(cfg)$distribution,
                                        determinand[distribution %in% "normal"])),
  appendix.thresholds_note = cfg$report$thresholds_note
)

rmd_file <- file.path(report_dir, paste0("appendix_", cfg$run_name, ".Rmd"))
appendix(contents, rmd_file,
         sections = cfg$report$sections,
         exclude_maps = unlist(cfg$report$exclude_maps),
         header_values = appendix_header_values(cfg))
pdf_file <- rmarkdown::render(rmd_file, envir = new.env(), quiet = TRUE)

write_run_info(cfg, "step3", extra = list(report = basename(pdf_file)))
message("Step 3 done: ", pdf_file)
