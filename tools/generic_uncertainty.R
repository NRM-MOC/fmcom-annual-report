# Generic uncertainties for config/harsat/determinand.csv ----
#
# HARSAT uses biota_sd_constant and biota_sd_variable only for values without
# a reported uncertainty: SD = sqrt(sd_constant^2 + (sd_variable * value)^2).
# Both must be standard deviations: sd_constant in the determinand's
# biota_unit on a wet-weight basis (HARSAT converts it to the series' basis),
# sd_variable as a relative SD.
#
# Estimated as in HARSAT's own ctsm_uncrt_estimate(), from fmcom (marine and
# freshwater together, since both programmes use the same laboratories):
#   sd_variable: the labs report the expanded uncertainty (U2, k = 2), so the
#     relative SD is U2 / (2 * value). Median per laboratory, then median over
#     laboratories, using detected values with a relative SD of 1-100 %.
#   sd_constant: LOD / 3 (values reported as <LOD) or LOQ / 10 (<LOQ), the
#     same rule HARSAT applies to censored values. Median per laboratory, then
#     median over laboratories.
#
# Run from the project folder. Writes to output/tools/ and does not change
# determinand.csv unless `update_determinand` is TRUE. Determinands that
# can't be estimated (e.g. the biological variables) keep their current
# values.

library(tidyverse)

update_determinand <- FALSE

# Reported limits known to be wrong in fmcom (to be corrected in the data)
exclude_constant <- c("CB77", "CB189", "FLU")

out_dir <- here::here("output", "tools")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
determinand_file <- here::here("config", "harsat", "determinand.csv")
determinand <- read.csv(determinand_file, check.names = FALSE)

## fmcom values on a wet-weight basis in the determinand's unit ----
# fmcom units look like "ng.g-1.lw-1": amount per g, then basis
unit_factor <- c(ug = 1, ng = 1e-3, pg = 1e-6)            # to mg/kg
biota_unit_factor <- c("mg/kg" = 1, "ug/kg" = 1e-3, "ng/kg" = 1e-6)

data <- fmcom::fmcom |>
  filter(!is.na(value), value > 0) |>
  mutate(
    determinand = toupper(if_else(contaminant == "CB138and163", "CB138", as.character(contaminant))),
    prefix = str_extract(as.character(unit), "^[a-z]+"),
    basis = str_extract(as.character(unit), "(ww|dw|lw)"),
    to_ww = case_when(basis == "ww" ~ 1,
                      basis == "dw" ~ dry_weight_percentage / 100,
                      basis == "lw" ~ fat_percentage / 100)
  ) |>
  inner_join(select(determinand, determinand, biota_unit), by = "determinand") |>
  mutate(factor = unit_factor[prefix] / biota_unit_factor[biota_unit] * to_ww)

## sd_variable ----
relative <- data |>
  filter(!is_censored, LOQ_LOD != ">LOD, <LOQ", !is.na(uncertainty)) |>
  mutate(relative_sd = uncertainty / (2 * value))

implausible <- filter(relative, !between(relative_sd, 0.01, 1))
write_csv(select(implausible, water_type, year, laboratory, substance_group, contaminant,
                 value, uncertainty, unit, relative_sd, specimen_ID, sample_ID),
          file.path(out_dir, "implausible_uncertainties.csv"))

sd_variable <- relative |>
  filter(between(relative_sd, 0.01, 1)) |>
  summarise(sd = median(relative_sd), n = n(), .by = c(determinand, laboratory)) |>
  summarise(new_sd_variable = median(sd), n_variable = sum(n),
            labs_variable = paste(sort(laboratory), collapse = " "), .by = determinand)

## sd_constant ----
sd_constant <- data |>
  filter(LOQ_LOD %in% c("<LOD", "<LOQ"), !determinand %in% exclude_constant,
         !is.na(factor)) |>
  mutate(sd = value * factor / if_else(LOQ_LOD == "<LOD", 3, 10)) |>
  summarise(sd = median(sd), n = n(), .by = c(determinand, laboratory)) |>
  summarise(new_sd_constant = median(sd), n_constant = sum(n),
            labs_constant = paste(sort(laboratory), collapse = " "), .by = determinand)

## Comparison with the current values ----
comparison <- determinand |>
  filter(biota_assess %in% TRUE) |>
  select(determinand, biota_group, biota_unit,
         current_sd_constant = biota_sd_constant, current_sd_variable = biota_sd_variable) |>
  left_join(sd_constant, by = "determinand") |>
  left_join(sd_variable, by = "determinand") |>
  mutate(across(starts_with("new_"), \(x) signif(x, 4)),
         ratio_sd_variable = round(new_sd_variable / current_sd_variable, 2),
         ratio_sd_constant = round(new_sd_constant / current_sd_constant, 2))
write_csv(comparison, file.path(out_dir, "generic_uncertainty_comparison.csv"), na = "")

message("Written to ", out_dir, ": generic_uncertainty_comparison.csv (",
        sum(!is.na(comparison$new_sd_variable)), " sd_variable and ",
        sum(!is.na(comparison$new_sd_constant)), " sd_constant estimated of ",
        nrow(comparison), " assessed determinands), implausible_uncertainties.csv (",
        nrow(implausible), " rows outside 1-100 %)")

## Optionally update determinand.csv ----
if (update_determinand) {
  updated <- determinand |>
    left_join(select(comparison, determinand, new_sd_constant, new_sd_variable), by = "determinand") |>
    mutate(biota_sd_constant = coalesce(new_sd_constant, biota_sd_constant),
           biota_sd_variable = coalesce(new_sd_variable, biota_sd_variable)) |>
    select(-new_sd_constant, -new_sd_variable)
  write_csv(updated, determinand_file, na = "")
  message("Updated ", determinand_file)
}
