# Step 1: new year's raw data -> fmcom format ----
#
# Mirrors fmcom's data-raw/adding_next_year_fmcom.R, which converts the SGU
# download into fmcom rows. Here we start from the lab files read with MoCiS2,
# i.e. the same data before it is submitted to SGU, so the new year looks the
# way it will in fmcom next year. Deliberate differences from the fmcom script
# are marked "Differs from fmcom".

## Translation tables (as in adding_next_year_fmcom.R) ----
species_latin <- c(Sill = "Clupea harengus", Stromming = "Clupea harengus",
                   Torsk = "Gadus morhua", Abborre = "Perca fluviatilis",
                   Tanglake = "Zoarces viviparus", Blamussla = "Mytilus edulis",
                   Sillgrissla = "Uria aalge", Fisktarna = "Sterna hirundo",
                   Strandskata = "Haematopus ostralegus", Roding = "Salvelinus alpinus",
                   Gadda = "Esox lucius", Mort = "Rutilus rutilus")
species_english <- c(Sill = "Atlantic herring", Stromming = "Atlantic herring",
                     Torsk = "Atlantic cod", Abborre = "European perch",
                     Tanglake = "Viviparous eelpout", Blamussla = "Blue mussel",
                     Sillgrissla = "Common guillemot", Fisktarna = "Common Tern",
                     Strandskata = "Eurasian oystercatcher", Roding = "Arctic char",
                     Gadda = "northern pike", Mort = "Roach")
species_class <- c("Clupea harengus" = "Fish", "Gadus morhua" = "Fish",
                   "Perca fluviatilis" = "Fish", "Zoarces viviparus" = "Fish",
                   "Salvelinus alpinus" = "Fish", "Esox lucius" = "Fish",
                   "Rutilus rutilus" = "Fish", "Uria aalge" = "Bird",
                   "Sterna hirundo" = "Bird", "Haematopus ostralegus" = "Bird",
                   "Mytilus edulis" = "Bivalve")
unit_english <- c("ug.g-1.tv-1" = "ug.g-1.dw-1", "ng.g-1.vv-1" = "ng.g-1.ww-1",
                  "ng.g-1.tv-1" = "ng.g-1.dw-1", "ng.g-1.lv-1" = "ng.g-1.lw-1",
                  "pg.g-1.lv-1" = "pg.g-1.lw-1", "ug.g-1.lv-1" = "ug.g-1.lw-1")
organ_english <- c(LEVER = "Liver", MUSKEL = "Muscle", MJUKKROPP = "Soft tissue",
                   HELKROPP = "Whole ind", AGG = "Egg content")
sex_english <- c(M = "Male", F = "Female", X = "Mixed", H = "Hermaphrodite",
                 I = "Immature", U = NA)
laboratory_short <- c(UMU_KEM_INST = "UMU", LIVSMEDELSVERKET = "SFA", ACES = "SU",
                      SLU = "SLU", IVL = "IVL")

# SGU codes for biological data (one value per specimen) and for fat and dry
# weight percentages (one value per lab sample), as in adding_next_year_fmcom.R
bio_codes <- c("CH02/90", "CH04/8", "CH04/9", "CH08/15", "CH12/161", "CH12/163",
               "CH12/232", "CH12/234", "CH12/239", "CH12/241")
fraction_codes <- c("CH12/68", "CH12/224")

lookup <- function(x, table) unname(table[x])

## fmcom master tables ----
# Read from the fmcom GitHub repo at the commit of the installed fmcom package,
# so the tables match the data. Falls back to "master" if fmcom was not
# installed from GitHub.
master_tables_ref <- function() {
  sha <- utils::packageDescription("fmcom")$RemoteSha
  if (is.null(sha)) "master" else sha
}

load_master_table <- function(name, ref = master_tables_ref()) {
  url <- paste0("https://raw.githubusercontent.com/NRM-MOC/fmcom/", ref,
                "/data-raw/master_tables/", name, ".csv")
  utils::read.csv(url, na.strings = c("", "NA"), encoding = "UTF-8",
                  colClasses = "character") |>
    # A stray space (e.g. "NADONA ") would silently break a join
    dplyr::mutate(dplyr::across(dplyr::everything(), trimws))
}

load_master_tables <- function(ref = master_tables_ref()) {
  list(
    ref = ref,
    stations = load_master_table("stations_SGU_NRM", ref) |>
      dplyr::transmute(station, station_name,
                       station_code_SGU = as.integer(station_code_SGU),
                       latitude = as.numeric(latitude), longitude = as.numeric(longitude),
                       water_type, HELCOM_basin, ICES_basin,
                       ICES_station = as.numeric(ICES_station)),
    contaminants = load_master_table("contaminants_SGU_NRM", ref) |>
      dplyr::select(contaminant, substance_group, contaminant_full_name,
                    contaminant_alt_name, CAS_number,
                    contaminant_code_SGU = UNIK_PARAMETERKOD),
    methods = load_master_table("analytical_method_SGU_NRM", ref)
  )
}

## Lab files ----
# Reads the lab files listed in the config with MoCiS2. MoCiS2's warnings
# (unmatched stations, species or codes) are kept for the QC output.
read_lab_files <- function(cfg) {
  dir <- data_dir(cfg$raw_data$lab_files_dir)
  entries <- cfg$raw_data$lab_files
  listed <- vapply(entries, `[[`, "", "file")

  present <- list.files(dir, pattern = "\\.xlsm$")
  present <- present[!startsWith(present, "~$")]   # Excel lock files
  missing <- setdiff(listed, present)
  if (length(missing) > 0) {
    stop("Lab files listed in the config but not found in ", dir, ": ",
         paste(missing, collapse = ", "), call. = FALSE)
  }

  messages <- list()
  duplicates <- list()
  data <- purrr::map(entries, function(entry) {
    msgs <- character()
    d <- withCallingHandlers(
      MoCiS2::moc_read_lab(file.path(dir, entry$file),
                           negative_for_nondetect = entry$negative_for_nondetect %||% TRUE),
      message = function(m) {
        msgs <<- c(msgs, trimws(conditionMessage(m)))
        invokeRestart("muffleMessage")
      }
    )
    if (length(msgs) > 0) {
      messages[[entry$file]] <<- paste(msgs, collapse = " ")
    }
    # A code listed twice in a lab file's accreditation list makes MoCiS2
    # repeat every row for that code; identical rows are removed and counted
    n_before <- nrow(d)
    d <- dplyr::distinct(d)
    if (nrow(d) < n_before) duplicates[[entry$file]] <<- n_before - nrow(d)
    d |>
      dplyr::mutate(lab_file = entry$file,
                    dplyr::across(c(ANALYS_DAT, DWEIGHT, WWEIGHT), as.character))
  }) |>
    dplyr::bind_rows() |>
    # The metals file also reports dry weight as TPRC for samples whose dry
    # weight comes with the Hg file (TPRCI); keep one, as the SGU submission
    # script does
    dplyr::filter(NRM_PARAMETERKOD != "TPRC")

  # as.character()/as.integer() keep the columns when there is nothing to report
  list(data = data,
       messages = tibble::tibble(lab_file = as.character(names(messages)),
                                 message = as.character(unlist(messages))),
       duplicates = tibble::tibble(lab_file = as.character(names(duplicates)),
                                   n = as.integer(unlist(duplicates))),
       unlisted_files = setdiff(present, listed))
}

## Method rules ----
# Corrections to the analytical method that apply every year, e.g. egg content
# needs a different extraction method than the one reported for all tissues.
# Matching on the reported method means fat % rows (EJ_REL) are never changed.
apply_method_rules <- function(lab, rules = read_method_rules()) {
  lab |>
    dplyr::left_join(dplyr::select(rules, ORGAN = organ, ANALYS_MET = method_reported,
                                   method_corrected),
                     by = c("ORGAN", "ANALYS_MET")) |>
    dplyr::mutate(ANALYS_MET = dplyr::coalesce(method_corrected, ANALYS_MET)) |>
    dplyr::select(-method_corrected)
}

read_method_rules <- function() {
  utils::read.csv(here::here("config", "method_rules.csv"), colClasses = "character",
                  encoding = "UTF-8")
}

## Biological data (esbase) ----
# As in the SGU submission script. Sex uses SGU codes, which
# MoCiS2::moc_join_SGU() needs to pool sexes correctly.
read_esbase <- function(cfg) {
  raw <- readxl::read_excel(data_dir(cfg$raw_data$esbase_file), guess_max = 100000)
  # Mussel and egg lengths (mm) have their own columns, present only when
  # mussel and bird data is included in the extract
  for (col in c("Mussellängd", "ägglängd")) {
    if (!col %in% names(raw)) raw[[col]] <- NA_real_
  }
  birds <- c("Uria aalge", "Sterna hirundo", "Haematopus ostralegus")
  raw |>
    dplyr::transmute(
      PROV_KOD_ORIGINAL = ACCNR_ESBASE,
      PROVTAG_DAT = as.Date(DATE),
      KON = dplyr::case_when(
        SPECIES %in% birds ~ "I",
        SPECIES == "Mytilus edulis" ~ "H",
        SEX %in% c("male", "Hane", "1") ~ "M",
        SEX %in% c("female", "Hona", "2") ~ "F"),
      TOTV = as.numeric(TOTV),
      TOTL = dplyr::case_when(
        SPECIES == "Mytilus edulis" ~ as.numeric(Mussellängd) / 10,
        SPECIES %in% birds ~ as.numeric(ägglängd) / 10,
        TRUE ~ as.numeric(TOTL)),
      ALDR = as.numeric(ALDR)
    )
}

## Season ----
# Same rule as fmcom. Differs from fmcom: the day is compared as a number
# (fmcom's zero-padded text comparison leaves 1-9 July without a season).
assign_season <- function(date) {
  month <- as.integer(format(date, "%m"))
  day <- as.integer(format(date, "%d"))
  dplyr::case_when(
    month %in% 1:2 ~ "Winter",
    month %in% 3:6 ~ "Spring",
    month == 7 & day <= 15 ~ "Spring",
    month %in% 7:12 ~ "Autumn"
  )
}

## Censoring flag ----
# Differs from fmcom: SGU's download only gives matvstd (q/b), so a value
# between LOD and LOQ comes back as "<LOQ". MoCiS2 also flags it in
# MATVARDESPAR ("Ja"), which we keep as ">LOD, <LOQ".
censoring_flag <- function(MATV_STD, MATVARDESPAR) {
  dplyr::case_when(
    MATVARDESPAR %in% "Ja" ~ "Ja",
    MATV_STD %in% c("q", "b") ~ MATV_STD
  )
}

## Convert to fmcom format ----
# `year` is used for samples without a sampling date (no esbase match).
to_fmcom_format <- function(lab, bio, master, year) {
  joined <- MoCiS2::moc_join_SGU(bio, apply_method_rules(lab), add_bio_pars = TRUE)

  ### Same columns as the SGU download in adding_next_year_fmcom.R ----
  data_new0 <- joined |>
    dplyr::transmute(
      specimen_ID = PROV_KOD_ORIGINAL,
      date = as.Date(PROVTAG_DAT),
      year = dplyr::coalesce(as.numeric(format(date, "%Y")), as.numeric(year)),
      station_code_SGU = as.integer(PROVPLATS_ID),
      contaminant_code_SGU = UNIK_PARAMETERKOD,
      value = as.numeric(MATVARDETAL),
      enhet = ENHET,
      matvstd = censoring_flag(MATV_STD, MATVARDESPAR),
      uncertainty = as.numeric(MATOSAKERHET),
      art = ART,
      organ = ORGAN,
      kon = KON,
      number_individuals = as.numeric(ANTAL),
      sample_ID = RAPPORT_KOD_LABB,
      laboratorium = LABB,
      analysinstrument = ANALYS_INSTR,
      analysmetod = ANALYS_MET
    ) |>
    dplyr::left_join(master$stations, by = "station_code_SGU") |>
    dplyr::left_join(master$contaminants, by = "contaminant_code_SGU")

  ### Biological data per specimen, fat and dry weight % per lab sample ----
  bio_data <- data_new0 |>
    dplyr::filter(contaminant_code_SGU %in% bio_codes) |>
    dplyr::select(specimen_ID, contaminant, value) |>
    tidyr::pivot_wider(names_from = contaminant, values_from = value, values_fn = mean)
  frac_data <- data_new0 |>
    dplyr::filter(contaminant_code_SGU %in% fraction_codes) |>
    dplyr::distinct(sample_ID, contaminant, value) |>
    tidyr::pivot_wider(names_from = contaminant, values_from = value, values_fn = mean)

  data_new0 |>
    dplyr::filter(substance_group != "Biological" | is.na(substance_group)) |>
    dplyr::mutate(
      species = lookup(art, species_latin),
      species_EN = lookup(art, species_english),
      class = lookup(species, species_class),
      unit = lookup(enhet, unit_english),
      organ = dplyr::coalesce(lookup(organ, organ_english), organ),
      sex = lookup(kon, sex_english),
      season = assign_season(date),
      LOQ_LOD = dplyr::case_when(
        is.na(matvstd) ~ ">LOQ",
        matvstd == "q" ~ "<LOQ",
        matvstd == "b" ~ "<LOD",
        matvstd == "Ja" ~ ">LOD, <LOQ"),
      is_censored = !is.na(matvstd),
      laboratory = lookup(laboratorium, laboratory_short)
    ) |>
    dplyr::left_join(master$methods, by = c("analysmetod" = "SGU_analytical.method",
                                            "analysinstrument" = "SGU_instrument")) |>
    dplyr::left_join(bio_data, by = "specimen_ID") |>
    add_missing_columns(c("age", "total_length", "weight", "d13C", "d15N",
                          "C_dw_percentage", "N_dw_percentage")) |>
    dplyr::mutate(age = ifelse(organ == "Egg content", 0, age)) |>
    dplyr::left_join(frac_data, by = "sample_ID") |>
    # Only liver is used for PFAS
    dplyr::filter(!(substance_group %in% "PFAS" & organ == "Muscle")) |>
    match_fmcom_columns()
}

# Columns that may be absent in a given year (e.g. no isotopes) become NA
add_missing_columns <- function(data, cols) {
  for (col in setdiff(cols, names(data))) data[[col]] <- NA_real_
  data
}

# Same columns, in the same order, as fmcom, plus `source` to tell the new
# year apart when it is combined with fmcom.
match_fmcom_columns <- function(data) {
  cols <- names(fmcom::fmcom)
  data <- add_missing_columns(data, cols)
  data$suspected_outlier <- as.logical(data$suspected_outlier)   # not assessed for the new year
  data$source <- "new_year"
  data[, c(cols, "source")]
}
