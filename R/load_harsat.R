# HARSAT ----
#
# During HARSAT development, set HARSAT_DEV_PATH in .Renviron to a local
# HARSAT checkout; it is then loaded with load_all(). Otherwise the
# installed (renv-pinned) harsat package is used.

load_harsat <- function() {
  dev_path <- Sys.getenv("HARSAT_DEV_PATH")
  if (nzchar(dev_path)) {
    pkgload::load_all(dev_path, export_all = FALSE, quiet = TRUE)
    message("HARSAT: development copy loaded from ", dev_path)
  } else {
    if (!requireNamespace("harsat", quietly = TRUE)) {
      stop("HARSAT not found. Set HARSAT_DEV_PATH in .Renviron to your local ",
           "HARSAT checkout, or install the harsat package.", call. = FALSE)
    }
    library(harsat)
    message("HARSAT: installed package ", utils::packageVersion("harsat"))
  }
  invisible(harsat_version())
}

## Version of HARSAT in use, for the run record ----
harsat_version <- function() {
  dev_path <- Sys.getenv("HARSAT_DEV_PATH")
  if (nzchar(dev_path)) {
    desc <- read.dcf(file.path(dev_path, "DESCRIPTION"), fields = "Version")
    commit <- tryCatch(
      system2("git", c("-C", shQuote(dev_path), "rev-parse", "HEAD"), stdout = TRUE),
      error = function(e) NA_character_, warning = function(w) NA_character_
    )
    list(source = "development copy", version = unname(desc[1, "Version"]), commit = commit)
  } else {
    desc <- utils::packageDescription("harsat")
    list(source = "installed package", version = desc$Version,
         commit = if (is.null(desc$RemoteSha)) NA_character_ else desc$RemoteSha)
  }
}
