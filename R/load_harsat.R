# HARSAT ----
#
# Uses HARSAT if it is already loaded in the session (e.g. with
# devtools::load_all() from a local checkout). Otherwise loads the copy in
# HARSAT_DEV_PATH (.Renviron) if set, or else the installed harsat package.

load_harsat <- function() {
  dev_path <- Sys.getenv("HARSAT_DEV_PATH")
  if (isNamespaceLoaded("harsat")) {
    message("HARSAT: using the copy already loaded (", harsat_path(), ")")
  } else if (nzchar(dev_path)) {
    pkgload::load_all(dev_path, export_all = FALSE, quiet = TRUE)
    message("HARSAT: development copy loaded from ", dev_path)
  } else {
    if (!requireNamespace("harsat", quietly = TRUE)) {
      stop("HARSAT not found. Load it with devtools::load_all(), set HARSAT_DEV_PATH ",
           "in .Renviron to your local HARSAT checkout, or install the harsat package.",
           call. = FALSE)
    }
    message("HARSAT: installed package ", utils::packageVersion("harsat"))
  }
  invisible(harsat_version())
}

harsat_path <- function() getNamespaceInfo("harsat", "path")

## Version of HARSAT in use, for the run record ----
harsat_version <- function() {
  path <- harsat_path()
  desc <- read.dcf(file.path(path, "DESCRIPTION"))
  field <- function(f) if (f %in% colnames(desc)) unname(desc[1, f]) else NA_character_
  # A development copy is a git checkout; an installed package records the
  # GitHub commit it was installed from
  commit <- tryCatch(
    system2("git", c("-C", shQuote(path), "rev-parse", "HEAD"), stdout = TRUE, stderr = FALSE),
    error = function(e) NA_character_, warning = function(w) NA_character_
  )
  if (length(commit) == 0 || is.na(commit[1])) commit <- field("RemoteSha")
  list(path = path, version = field("Version"), commit = commit[1])
}
