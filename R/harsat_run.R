# Step 2b: run HARSAT ----

## Sums and weighted sums (config/harsat/determinand_sums.yml) ----
# Returns the determinands.control list that create_timeseries() expects
harsat_sums <- function() {
  sums <- yaml::read_yaml(here::here("config", "harsat", "determinand_sums.yml"))
  weights <- lapply(sums, function(s) unlist(s$weights))
  lapply(sums, function(s) {
    if (!is.null(s$weights)) {
      w <- unlist(s$weights)
    } else if (!is.null(s$combine)) {
      w <- unlist(unname(weights[unlist(s$combine)]))
    } else {
      return(list(det = unlist(s$det), action = "sum"))
    }
    list(det = names(w), action = "sum", weights = w)
  })
}

## Run one group ----
# Saves the assessment before and after convergence fixes, and returns the
# convergence log.
run_harsat_group <- function(cfg, group) {
  message("\n== HARSAT: ", group)
  data <- harsat::read_data(
    compartment = "biota",
    purpose = "custom",
    contaminants = paste0("NRM_", group, ".csv"),
    stations = "stations.csv",
    data_dir = harsat_dir(cfg, "data"),
    data_format = "external",
    info_dir = here::here("config", "harsat"),
    oddity_dir = harsat_dir(cfg, "oddities", group),
    control = list(region = list(id = "regionLevel2"))
  )
  data <- harsat::tidy_data(data)

  timeseries <- harsat::create_timeseries(
    data,
    get_basis = get_basis_nrm,
    determinands.control = harsat_sums()
  )

  assessment <- harsat::run_assessment(
    timeseries,
    recent_trend = as.integer(cfg$harsat$recent_trend),
    AC = c("EQS", "EAC"),
    parallel = TRUE
  )
  saveRDS(assessment, file.path(harsat_dir(cfg, "assessments"), paste0(group, "_unfixed.rds")))

  fixed <- fix_convergence(assessment)
  saveRDS(fixed$assessment, file.path(harsat_dir(cfg, "assessments"), paste0(group, ".rds")))
  dplyr::mutate(fixed$log, group = group, .before = 1)
}

## Convergence fixes ----
# For each time series that did not converge: diagnose why, then try the
# fixes in config/harsat/convergence_fixes.yml (those matching the diagnosis
# first), refitting only that series, and keep the first fix that converges.
fix_convergence <- function(assessment, fixes = read_convergence_fixes()) {
  not_converged <- harsat_not_converged(assessment)
  log <- purrr::map(not_converged, function(series) {
    diagnosis <- diagnose_convergence(assessment$assessment[[series]])
    tried <- character()
    for (fix in order_fixes(fixes, diagnosis)) {
      label <- fix_label(fix)
      tried <- c(tried, label)
      args <- c(list(assessment, subset = call("==", as.name("series"), series)), fix)
      updated <- suppressMessages(do.call(harsat::update_assessment, args))
      if (identical(updated$assessment[[series]]$convergence, 0L)) {
        assessment <<- updated
        return(tibble::tibble(series = series, diagnosis = diagnosis,
                              tried = paste(tried, collapse = " | "), resolved_with = label))
      }
    }
    tibble::tibble(series = series, diagnosis = diagnosis,
                   tried = paste(tried, collapse = " | "), resolved_with = NA_character_)
  })
  list(assessment = assessment,
       log = dplyr::bind_rows(tibble::tibble(series = character(), diagnosis = character(),
                                             tried = character(), resolved_with = character()),
                              log))
}

harsat_not_converged <- function(assessment) {
  utils::capture.output(result <- harsat::check_assessment(assessment, save_result = TRUE))
  if (is.null(result)) character() else result$not_converged
}

read_convergence_fixes <- function() {
  yaml::read_yaml(here::here("config", "harsat", "convergence_fixes.yml"))$fixes
}

# Why a series did not converge, using the same checks as HARSAT's
# check_convergence_lmm()
diagnose_convergence <- function(a, coeff_se_tol = 0.001) {
  if ("error" %in% names(a)) return("error")
  coeff <- a$coefficients
  random_id <- grepl("sd", row.names(coeff))
  fixed <- coeff[!random_id, , drop = FALSE]
  random <- coeff[random_id, , drop = FALSE]
  if (any(fixed$onBound)) return("fixed_bound")
  if (any(random$onBound & random$est > 0.0001)) return("random_bound")
  if (any(is.na(a$pred$se)) || any(is.na(fixed$se)) || min(fixed$se) < coeff_se_tol) {
    return("standard_error")
  }
  "other"
}

order_fixes <- function(fixes, diagnosis) {
  matching <- vapply(fixes, function(f) diagnosis %in% unlist(f$`for`), logical(1))
  lapply(c(fixes[matching], fixes[!matching]), function(f) f[names(f) != "for"])
}

fix_label <- function(fix) paste(names(fix), unlist(fix), sep = " = ", collapse = ", ")
