# Step 2a: fmcom + new year -> HARSAT input files ----
#
# Same conversion as the old Prepare_MCOM_raw_data.R, but for all groups in
# one go, and with HARSAT stations found by SGU ID (and season, for the
# stations sampled in both spring and autumn) instead of by name.

## Output folder for HARSAT, e.g. output/marine_2025/harsat/ ----
harsat_dir <- function(cfg, ...) output_dir(cfg, "harsat", ...)

## HARSAT codes ----
matrix_code <- c("Liver" = "LI", "Muscle" = "MU", "Soft tissue" = "SB", "Egg content" = "EH")
# Biological variables refer to the whole individual, shell or whole egg
bio_matrix_code <- c(LI = "WO", MU = "WO", SB = "SH", EH = "ES")
basis_from_unit <- c("ug.g-1.dw-1" = "D", "ng.g-1.dw-1" = "D", "ng.g-1.ww-1" = "W",
                     "ng.g-1.lw-1" = "L", "pg.g-1.lw-1" = "L", "ug.g-1.lw-1" = "L")
harsat_unit <- c("ug.g-1.dw-1" = "ug/g", "ng.g-1.dw-1" = "ng/g", "ng.g-1.ww-1" = "ng/g",
                 "ng.g-1.lw-1" = "ng/g", "pg.g-1.lw-1" = "pg/g", "ug.g-1.lw-1" = "ug/g")
censoring_code <- c("<LOQ" = "Q", "<LOD" = "D", "<LOQ or <LOD" = "Q", ">LOD, <LOQ" = "Q")

harsat_variables <- c("country", "station_code", "station_name", "year", "date", "species",
                      "n_individual", "sample", "determinand", "matrix", "unit", "value",
                      "basis", "censoring", "uncertainty", "unit_uncertainty")

load_harsat_stations <- function(cfg) {
  utils::read.csv(here::here("config", "harsat", cfg$harsat$stations_file),
                  check.names = FALSE, na.strings = "", encoding = "UTF-8")
}

## Convert one group's data ----
to_harsat_format <- function(data, stations) {
  spring_ids <- stations$station_code_SGU[stations$season %in% "Spring"]

  nrm <- data |>
    # One fat % per lab sample
    dplyr::mutate(fat_percentage = stats::median(fat_percentage), .by = sample_ID) |>
    # CB138 and CB163 could not be separated in older analyses (SU, marine
    # 1987-2019); SFA reports CB138 alone from 2020. CB163 is small compared to
    # the changes in CB138 over time, so the combined value is used as CB138
    # to show the overall trend (a slight overestimate in early years). The
    # two periods do not overlap and have the same unit.
    dplyr::mutate(contaminant = dplyr::if_else(contaminant == "CB138and163", "CB138",
                                               contaminant)) |>
    # Spring samples at the stations sampled in both seasons are separate
    # HARSAT stations (e.g. Angskarsklubb_S)
    dplyr::mutate(harsat_season = dplyr::if_else(
      season %in% "Spring" & station_code_SGU %in% spring_ids, "Spring", NA_character_)) |>
    dplyr::select(-station_name) |>
    dplyr::left_join(
      dplyr::select(stations, station_code_SGU, harsat_season = season,
                    country, station_code, station_name),
      by = c("station_code_SGU", "harsat_season")) |>
    dplyr::rename(n_individual = number_individuals, sample = sample_ID) |>
    dplyr::mutate(
      sex = dplyr::if_else(sex == "Female", "F", dplyr::if_else(sex == "Male", "M", "X")),
      matrix = dplyr::coalesce(lookup(organ, matrix_code), organ),
      basis = lookup(unit, basis_from_unit),
      unit = lookup(unit, harsat_unit),
      censoring = dplyr::coalesce(lookup(LOQ_LOD, censoring_code), ""),
      # Uncertainty as % of the value
      uncertainty = uncertainty / value * 100,
      unit_uncertainty = dplyr::if_else(is.na(uncertainty), "", "%")
    )

  # Fat %, dry weight % and biological variables as extra determinands
  dry <- harsat_aux(nrm, "dry_weight_percentage", "DRYWT%", "%", basis = "W")
  fat <- harsat_aux(nrm, "fat_percentage", "LIPIDWT%", "%", basis = "W")
  length <- harsat_aux(nrm, "total_length", "LNMEA", "cm", basis = "", bio_matrix = TRUE)
  weight <- harsat_aux(nrm, "weight", "WTMEA", "g", basis = "W", bio_matrix = TRUE)
  age <- harsat_aux(nrm, "age", "AGMEA", "y", basis = "", bio_matrix = TRUE) |>
    dplyr::filter(value != 0)

  nrm |>
    dplyr::rename(determinand = contaminant) |>
    dplyr::select(dplyr::all_of(harsat_variables)) |>
    dplyr::bind_rows(dry, fat, length, weight, age)
}

harsat_aux <- function(nrm, column, determinand, unit, basis, bio_matrix = FALSE) {
  out <- nrm |>
    dplyr::filter(!is.na(.data[[column]])) |>
    # .env: the function arguments, not the data columns with the same names
    dplyr::mutate(value = .data[[column]], determinand = .env$determinand,
                  unit = .env$unit, basis = .env$basis, censoring = NA_character_,
                  uncertainty = NA_real_, unit_uncertainty = NA_character_)
  if (bio_matrix) out$matrix <- lookup(out$matrix, bio_matrix_code)
  out |>
    dplyr::select(dplyr::all_of(harsat_variables)) |>
    dplyr::distinct()
}

## Write HARSAT input for all groups ----
# One NRM_<group>.csv per group, plus stations.csv in the same folder (HARSAT
# reads both from data_dir). Returns the number of rows per group.
write_harsat_input <- function(cfg, data) {
  dir <- harsat_dir(cfg, "data")
  stations <- load_harsat_stations(cfg)
  utils::write.csv(dplyr::select(stations, -station_code_SGU, -season),
                   file.path(dir, "stations.csv"), na = "", row.names = FALSE)

  # Species not assessed in this programme (config harsat: exclude_species:)
  data <- dplyr::filter(data, !species %in% unlist(cfg$harsat$exclude_species))

  rows <- vapply(names(cfg$harsat$groups), function(group) {
    settings <- cfg$harsat$groups[[group]]
    input <- if (isTRUE(settings$biological)) {
      harsat_bio_input(data, stations, cfg$harsat$biological)
    } else {
      to_harsat_format(dplyr::filter(data, substance_group %in% settings$fmcom), stations)
    }
    utils::write.csv(input, file.path(dir, paste0("NRM_", group, ".csv")),
                     na = "", row.names = FALSE)
    nrow(input)
  }, integer(1))
  rows
}

## Input for the biological run ----
# The biological variables are in every group's input (lipid and dry weight %
# are needed there for basis conversion) but are assessed only in their own
# run. Its input takes each variable from one source, so nothing is counted
# twice (`rules`: config harsat: biological:).
harsat_bio_input <- function(data, stations, rules) {
  keep <- function(d, determinands) {
    dplyr::filter(to_harsat_format(d, stations), determinand %in% determinands)
  }
  # Age, length and weight belong to the specimen, not the lab sample: one
  # value per specimen, whichever lab samples it was in
  per_specimen <- data |>
    dplyr::mutate(sample_ID = specimen_ID) |>
    dplyr::distinct(specimen_ID, organ, .keep_all = TRUE)
  lipid <- dplyr::filter(data, laboratory %in% unlist(rules$lipid_laboratory),
                         organ %in% unlist(rules$lipid_organs))
  dry <- dplyr::filter(data, contaminant %in% unlist(rules$dry_weight_from))
  dplyr::bind_rows(
    keep(per_specimen, c("AGMEA", "LNMEA", "WTMEA")),
    keep(lipid, "LIPIDWT%"),
    keep(dry, "DRYWT%")
  ) |>
    dplyr::distinct()
}
