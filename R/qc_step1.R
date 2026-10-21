# QC for step 1 ----
#
# Scripted checks on the new year's data. Each row of the result is one check:
# how many items it found and which ones. An empty `details` means the check
# passed. Visual QC (plots against the historical range) comes later.

qc_step1 <- function(cfg, lab, bio, new_year, master) {
  d <- lab$data
  contaminant_rows <- d |>
    dplyr::filter(!UNIK_PARAMETERKOD %in% c(bio_codes, fraction_codes))

  method_keys <- paste(master$methods$SGU_analytical.method, master$methods$SGU_instrument)
  no_bio <- new_year |> dplyr::filter(is.na(date)) |> dplyr::distinct(species, specimen_ID)
  winter <- new_year |> dplyr::filter(season %in% "Winter") |> dplyr::distinct(species, specimen_ID)
  other_year <- new_year |> dplyr::filter(!is.na(date), year != cfg$year) |>
    dplyr::distinct(specimen_ID, date)

  fraction_duplicates <- d |>
    dplyr::filter(UNIK_PARAMETERKOD %in% fraction_codes) |>
    dplyr::group_by(RAPPORT_KOD_LABB, UNIK_PARAMETERKOD) |>
    dplyr::filter(dplyr::n_distinct(MATVARDETAL) > 1) |>
    dplyr::ungroup() |>
    dplyr::distinct(RAPPORT_KOD_LABB, NRM_PARAMETERKOD)

  # esbase holds every specimen caught, not only those analysed, so this is
  # reported as a count per species
  analysed_species <- unique(stats::na.omit(new_year$species))
  lab_specimens <- unpool_ids(unique(d$PROV_KOD_ORIGINAL))
  esbase_only <- readxl::read_excel(data_dir(cfg$raw_data$esbase_file), guess_max = 100000) |>
    dplyr::filter(SPECIES %in% analysed_species, !ACCNR_ESBASE %in% lab_specimens) |>
    dplyr::count(SPECIES)

  dplyr::bind_rows(
    qc_item("Lab files in the folder but not listed in the config", lab$unlisted_files),
    qc_item("MoCiS2 warnings when reading lab files",
            paste0(lab$messages$lab_file, ": ", lab$messages$message, recycle0 = TRUE)),
    qc_item("Identical rows from a lab file (removed)",
            paste0(lab$duplicates$lab_file, ": ", lab$duplicates$n, " rows", recycle0 = TRUE)),
    qc_item("Stations not in the fmcom master table (SGU ID)",
            paste(d$PROVPLATS_ANALYSMALL, d$PROVPLATS_ID)[
              !as.integer(d$PROVPLATS_ID) %in% master$stations$station_code_SGU]),
    qc_item("Stations whose water type differs from the programme",
            unique(new_year$station_name[new_year$water_type != cfg$water_type])),
    qc_item("Substance codes not in the fmcom master table (SGU code)",
            paste(d$NRM_PARAMETERKOD, d$UNIK_PARAMETERKOD)[
              !d$UNIK_PARAMETERKOD %in% master$contaminants$contaminant_code_SGU]),
    qc_item("Species without a translation", d$ART[!d$ART %in% names(species_latin)]),
    qc_item("Units without a translation",
            contaminant_rows$ENHET[!contaminant_rows$ENHET %in% names(unit_english)]),
    qc_item("Organs without a translation", d$ORGAN[!d$ORGAN %in% names(organ_english)]),
    qc_item("Laboratories without a short name",
            d$LABB[!d$LABB %in% names(laboratory_short)]),
    qc_item("Method + instrument not in the fmcom method master table",
            with(contaminant_rows, paste(lab_file, ANALYS_MET, ANALYS_INSTR, sep = " | "))[
              !paste(contaminant_rows$ANALYS_MET, contaminant_rows$ANALYS_INSTR) %in% method_keys]),
    qc_item("Lab samples without biological data in esbase (no date; year set from config)",
            paste(no_bio$species, no_bio$specimen_ID)),
    qc_item("Esbase specimens of analysed species without lab data (count per species)",
            paste0(esbase_only$SPECIES, ": ", esbase_only$n, recycle0 = TRUE)),
    qc_item("Winter samples (excluded from the new-year data)",
            paste(winter$species, winter$specimen_ID)),
    qc_item("Samples dated outside the report year",
            paste(other_year$specimen_ID, other_year$date)),
    qc_item("Lab samples with more than one fat or dry weight % (mean used)",
            paste(fraction_duplicates$RAPPORT_KOD_LABB, fraction_duplicates$NRM_PARAMETERKOD))
  )
}

qc_item <- function(check, items) {
  items <- sort(unique(stats::na.omit(items)))
  tibble::tibble(check = check, n = length(items), details = paste(items, collapse = "; "))
}

# Expands pooled specimen IDs ("B2025/09461-09472") into individual IDs
unpool_ids <- function(ids) {
  unlist(lapply(ids, function(id) {
    if (!grepl("-", id)) return(id)
    head <- sub("/.*", "/", id)
    range <- as.integer(strsplit(sub(".*/", "", id), "-")[[1]])
    paste0(head, sprintf("%05d", range[1]:range[2]))
  }))
}
