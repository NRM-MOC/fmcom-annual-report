# Step 4: the new year's data -> submission file for the national database ----
#
# Run after the report, from run.R, which loads the settings (cfg) and
# functions. Reads the same lab files as step 1, with the esbase extract set
# under `submission:` in config/<programme>.yml, and fills SGU's template
# (config/submission/).
#
# Set `submission: version:` by hand: 1 for the first submission, raised only
# to resubmit after an upload. Re-runs during the QC replace the version's
# files. Once the SGU receipt (.msg) is saved in the version folder, the
# version is locked.
#
# Output in <data folder>/<programme>/submissions/<year>/v<version>/:
#   <template name>_<programme>_<year>_v<version>.xlsx   the file to upload
#   qc_step4.csv                 QC checks; review before uploading
#   changes_since_v<n>.csv       rows added, removed or changed since the
#                                last submitted version (from version 2)
#   run_info_step4.yml           code, data and template versions used

check_submission_version(cfg)
template <- submission_template()
version_dir <- submission_dir(cfg)
dir.create(version_dir, recursive = TRUE, showWarnings = FALSE)

lab <- read_lab_files(cfg)
bio <- read_esbase(cfg, file = cfg$submission$esbase_file)
sgu <- sgu_sheets(cfg, lab$data, bio, template)

submission_file <- file.path(version_dir, submission_file_name(cfg, template))
write_submission(cfg, sgu$data, template, submission_file)

previous <- last_submitted(cfg, template)
if (!is.null(previous)) {
  changes <- submission_changes(read_submission(previous$file), sgu$data)
  readr::write_csv(changes, file.path(version_dir, paste0("changes_since_v", previous$version, ".csv")),
                   na = "")
}

qc <- qc_step4(cfg, lab, bio, sgu$messages)
readr::write_csv(qc, file.path(version_dir, "qc_step4.csv"), na = "")
write_run_info(cfg, "step4", dir = version_dir, extra = list(
  version = cfg$submission$version,
  template = basename(template),
  template_version = template_version(template),
  lab_files = vapply(cfg$raw_data$lab_files, `[[`, "", "file"),
  esbase_file = cfg$submission$esbase_file,
  compared_with = if (!is.null(previous)) paste0("v", previous$version) else "none (first submission)",
  MoCiS2 = as.character(utils::packageVersion("MoCiS2"))
))

message("Step 4 done: ", basename(submission_file), " (",
        paste0(names(sgu$data), " ", vapply(sgu$data, nrow, integer(1)), " rows", collapse = ", "),
        ") in ", version_dir, ". QC: ", sum(qc$n > 0), " of ", nrow(qc),
        " checks found something; see qc_step4.csv",
        if (!is.null(previous)) paste0(". Changes since v", previous$version, ": ", nrow(changes), " rows"))
message("After uploading: save SGU's receipt (.msg) in that folder and add a row to config/submission/",
        basename(submission_log_file(cfg)))
