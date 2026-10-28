# Step 4: submission to the national database (SGU) ----
#
# Builds the submission file from the same lab files as step 1, with the
# esbase extract set under `submission:` in the config (often a later extract
# than the report's, with mussel and bird data). MoCiS2 converts the data to
# SGU's format; the result is written into SGU's blank template in
# config/submission/.
#
# Each submitted version has its own folder in the SGU folder (set by
# FMCOM_SUBMISSION_DIR in .Renviron), following its existing layout:
# <SGU folder>/<folder>/<folder> <year>/v<n>/, e.g. Marina/Marina 2025/v1/
# (`submission: folder:`). The version is set by hand
# (`submission: version:`). Re-runs replace the folder's contents until the
# SGU receipt (.msg) is saved there; after that the folder is locked.

submission_sheets_sgu <- c("PROVMETADATA", "PROVDATA_BIOTA", "DATA_MATVARDE")

# Keys used to match rows between two versions
submission_keys <- list(
  PROVMETADATA = "PROV_KOD_ORIGINAL",
  PROVDATA_BIOTA = "PROV_KOD_ORIGINAL",
  DATA_MATVARDE = c("PROV_KOD_ORIGINAL", "RAPPORT_KOD_LABB", "UNIK_PARAMETERKOD", "ORGAN", "LABB")
)

# moc_write_SGU()'s `program`: fixed values such as PROVPLATS_MILJO and PLATTFORM
sgu_program <- c(marine = "hav", freshwater = "limn")

## Template and folders ----
submission_template <- function() {
  files <- list.files(here::here("config", "submission"), pattern = "\\.xlsx$", full.names = TRUE)
  files <- files[!startsWith(basename(files), "~$")]   # Excel lock files
  if (length(files) != 1) {
    stop("config/submission/ should hold exactly one SGU template (.xlsx); found: ",
         if (length(files) == 0) "none" else paste(basename(files), collapse = ", "), call. = FALSE)
  }
  files
}

# The version on the template's front sheet ("Version:" in the first column)
template_version <- function(template) {
  front <- readxl::read_excel(template, sheet = 1, col_names = FALSE, .name_repair = "minimal")
  row <- which(trimws(front[[1]]) == "Version:")[1]
  if (is.na(row)) NA_character_ else as.character(front[[2]][row])
}

# The year's folder, e.g. Marina/Marina 2025/. Without FMCOM_SUBMISSION_DIR,
# output/submissions/ in the project (gitignored), e.g. for testing.
submission_year_dir <- function(cfg) {
  folder <- cfg$submission$folder
  if (is.null(folder)) {
    stop("Set `submission: folder:` in config/", cfg$programme, ".yml (e.g. Marina).", call. = FALSE)
  }
  root <- Sys.getenv("FMCOM_SUBMISSION_DIR", unset = here::here("output", "submissions"))
  file.path(root, folder, paste(folder, cfg$year))
}

submission_dir <- function(cfg, version = cfg$submission$version) {
  file.path(submission_year_dir(cfg), paste0("v", version))
}

# SGU's rules allow no spaces in the file name. Kept short: Windows paths
# can't be longer than 260 characters, and the SGU folder is on a network drive.
submission_file_name <- function(cfg, version = cfg$submission$version) {
  paste0("SGU_", cfg$run_name, "_v", version, ".xlsx")
}

receipts <- function(dir) list.files(dir, pattern = "\\.msg$", ignore.case = TRUE)

# Stops if the version has already been submitted (receipt saved in its
# folder); warns if the previous version has no receipt, i.e. the version
# may have been raised by mistake
check_submission_version <- function(cfg) {
  version <- cfg$submission$version
  if (is.null(version) || !is.numeric(version) || version < 1) {
    stop("Set `submission: version:` in config/", cfg$programme, ".yml (1 for the first submission).",
         call. = FALSE)
  }
  dir <- submission_dir(cfg)
  if (length(receipts(dir)) > 0) {
    stop("Version ", version, " has already been submitted: there is a receipt in ", dir,
         ". To resubmit, raise `submission: version:` in config/", cfg$programme, ".yml.",
         call. = FALSE)
  }
  if (version > 1 && length(receipts(submission_dir(cfg, version - 1))) == 0) {
    warning("Version ", version - 1, " has no receipt in ", submission_dir(cfg, version - 1),
            ". If it was never submitted, keep `submission: version:` at ", version - 1, ".",
            call. = FALSE)
  }
  invisible(dir)
}

# The latest earlier version with a receipt, and its submission file
last_submitted <- function(cfg) {
  earlier <- rev(seq_len(cfg$submission$version - 1))
  for (v in earlier) {
    dir <- submission_dir(cfg, v)
    if (length(receipts(dir)) == 0) next
    file <- file.path(dir, submission_file_name(cfg, v))
    if (!file.exists(file)) {
      xlsx <- list.files(dir, pattern = "\\.xlsx$", full.names = TRUE)
      xlsx <- xlsx[!startsWith(basename(xlsx), "~$")]
      if (length(xlsx) != 1) {
        warning("Version ", v, " has a receipt but no single submission file in ", dir,
                "; not compared.", call. = FALSE)
        return(NULL)
      }
      file <- xlsx
    }
    return(list(version = v, file = file))
  }
  NULL
}

## Data in SGU's format ----
# MoCiS2's moc_write_SGU() formats each sheet (fixed values, decimal comma,
# the template's columns) but writes a file of its own, with the template's
# explanation rows on top. We let it write to a temporary file and read the
# data rows back, so its formatting is used as it is.
sgu_sheets <- function(cfg, lab, bio, template) {
  joined <- MoCiS2::moc_join_SGU(bio, apply_method_rules(lab), add_bio_pars = TRUE)
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp))
  messages <- character()
  sheets <- purrr::map(stats::setNames(nm = submission_sheets_sgu), function(sheet) {
    withCallingHandlers(
      MoCiS2::moc_write_SGU(joined, sheet, tmp, mall_path = template,
                            program = sgu_program[[cfg$programme]]),
      message = function(m) {
        messages <<- c(messages, paste0(sheet, ": ", trimws(conditionMessage(m))))
        invokeRestart("muffleMessage")
      }
    )
    read_sgu_sheet(tmp, sheet = 1)
  })
  list(data = sheets, messages = messages)
}

# Data rows of a sheet in SGU's layout: column names in row 1, explanation
# rows (labelled in the first column) above the data, which has an empty
# first column. All values as text, as they are submitted.
read_sgu_sheet <- function(file, sheet) {
  d <- readxl::read_excel(file, sheet = sheet, col_types = "text", .name_repair = "minimal")
  d[is.na(d[[1]]), -1]
}

# BESTALLARE: from the config; RAPPORTNAMN is the report title
bestallare_row <- function(cfg, template) {
  columns <- names(readxl::read_excel(template, sheet = "BESTALLARE", n_max = 0, .name_repair = "minimal"))[-1]
  values <- cfg$submission$bestallare
  values$RAPPORTNAMN <- gsub("{year}", cfg$year, cfg$report$title, fixed = TRUE)
  unknown <- setdiff(names(values), columns)
  if (length(unknown) > 0) {
    stop("submission: bestallare: in config/", cfg$programme, ".yml has fields that are not in ",
         "the template's BESTALLARE sheet: ", paste(unknown, collapse = ", "), call. = FALSE)
  }
  row <- tibble::as_tibble(stats::setNames(as.list(rep(NA_character_, length(columns))), columns))
  row[names(values)] <- lapply(values, as.character)
  row
}

## Writing the submission file ----
# Data goes into the template from row 6 (below its five explanation rows),
# column B (column A holds the row labels), so SGU's layout and formatting
# are kept.
write_submission <- function(cfg, sheets, template, file) {
  wb <- openxlsx::loadWorkbook(template)
  write_rows <- function(sheet, data) {
    columns <- names(readxl::read_excel(template, sheet = sheet, n_max = 0, .name_repair = "minimal"))[-1]
    missing <- setdiff(columns, names(data))
    data[missing] <- NA_character_
    openxlsx::writeData(wb, sheet, data[columns], startCol = 2, startRow = 6, colNames = FALSE)
  }
  write_rows("BESTALLARE", bestallare_row(cfg, template))
  for (sheet in names(sheets)) write_rows(sheet, sheets[[sheet]])
  message_lines <- unlist(cfg$submission$message)
  if (length(message_lines) > 0) {
    write_rows("MEDDELANDE", tibble::tibble(MEDDEL = as.character(message_lines)))
  }
  started <- Sys.time()
  openxlsx::saveWorkbook(wb, file, overwrite = TRUE)
  # saveWorkbook() fails silently, e.g. when the path is too long for Windows
  if (!file.exists(file) || file.mtime(file) < started - 1) {
    stop("The submission file was not written: ", file, " (", nchar(file), " characters; ",
         "Windows allows 260). Use a shorter FMCOM_SUBMISSION_DIR or check that the folder ",
         "is writable and the file is not open in Excel.", call. = FALSE)
  }
  invisible(file)
}

## Changes since the last submitted version ----
# One row per added or removed row, and per changed value (rows matched on
# `submission_keys`). Rows whose key occurs more than once are reported as
# added/removed only.
submission_changes <- function(old, new) {
  purrr::map(names(submission_keys), function(sheet) {
    cols <- intersect(names(old[[sheet]]), names(new[[sheet]]))
    o <- dplyr::distinct(old[[sheet]][cols])
    n <- dplyr::distinct(new[[sheet]][cols])
    k <- submission_keys[[sheet]]
    removed <- dplyr::anti_join(o, n, by = cols)
    added <- dplyr::anti_join(n, o, by = cols)
    key_of <- function(d) do.call(paste, c(d[k], sep = " | "))
    once <- function(x) x[!x %in% x[duplicated(x)]]
    changed <- intersect(once(key_of(removed)), once(key_of(added)))

    long <- function(d, value) {
      d |>
        dplyr::mutate(key = key_of(d)) |>
        dplyr::filter(key %in% changed) |>
        dplyr::select(-dplyr::all_of(k)) |>
        tidyr::pivot_longer(-key, names_to = "column", values_to = value)
    }
    values_changed <- dplyr::inner_join(long(removed, "before"), long(added, "after"),
                                        by = c("key", "column")) |>
      dplyr::filter(dplyr::coalesce(before != after, is.na(before) != is.na(after))) |>
      dplyr::mutate(change = "changed")

    dplyr::bind_rows(
      tibble::tibble(change = "added", key = setdiff(key_of(added), changed)),
      tibble::tibble(change = "removed", key = setdiff(key_of(removed), changed)),
      values_changed
    ) |>
      dplyr::mutate(sheet = sheet, key_columns = paste(k, collapse = " | "), .before = 1)
  }) |>
    dplyr::bind_rows()
}

read_submission <- function(file) {
  purrr::map(stats::setNames(nm = submission_sheets_sgu), function(sheet) read_sgu_sheet(file, sheet))
}

## Log of submissions ----
submission_log_file <- function(cfg) {
  here::here("config", "submission", paste0("submissions_", cfg$programme, ".csv"))
}

# Versions of this year with a receipt but no row in the log
unlogged_submissions <- function(cfg) {
  dirs <- list.dirs(submission_year_dir(cfg), recursive = FALSE)
  dirs <- dirs[grepl("^v[0-9]+$", basename(dirs))]   # other folders in the year's folder are left alone
  submitted <- basename(dirs)[vapply(dirs, function(d) length(receipts(d)) > 0, logical(1))]
  log <- utils::read.csv(submission_log_file(cfg), colClasses = "character")
  logged <- paste0("v", log$version[log$year == cfg$year])
  setdiff(submitted, logged)
}

## QC for step 4 ----
qc_step4 <- function(cfg, lab, bio, write_messages) {
  individuals <- lab_individuals(lab$data) |>
    dplyr::left_join(bio, by = c("individual" = "PROV_KOD_ORIGINAL")) |>
    dplyr::mutate(in_esbase = individual %in% bio$PROV_KOD_ORIGINAL)
  general_info <- lab_general_info(cfg)
  dplyr::bind_rows(
    qc_item("Lab files in the folder but not listed in the config", lab$unlisted_files),
    qc_item("MoCiS2 warnings when reading lab files",
            paste0(lab$messages$lab_file, ": ", lab$messages$message, recycle0 = TRUE)),
    qc_general_info(general_info),
    qc_item("Template columns MoCiS2 does not fill", write_messages),
    bio_item("Lab specimens not in the submission's esbase extract (no biological data)",
             individuals, !individuals$in_esbase),
    bio_item("Lab specimens without a collection date", individuals,
             individuals$in_esbase & is.na(individuals$PROVTAG_DAT)),
    bio_item("Lab specimens without weight", individuals,
             individuals$in_esbase & is.na(individuals$TOTV)),
    bio_item("Lab specimens without age", individuals,
             individuals$in_esbase & is.na(individuals$ALDR)),
    bio_item("Lab specimens without sex", individuals,
             individuals$in_esbase & is.na(individuals$KON)),
    qc_item(paste0("Submitted versions (receipt saved) missing from config/submission/",
                   basename(submission_log_file(cfg))),
            unlogged_submissions(cfg))
  )
}
