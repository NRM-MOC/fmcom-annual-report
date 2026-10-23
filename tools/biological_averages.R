# Average dry weight % and lipid weight % for config/harsat/species.csv ----
#
# HARSAT uses these averages (columns MU_drywt, LI_lipidwt, ...) when it
# needs to convert between bases and the sample has no measured value.
# Calculated from fmcom, marine and freshwater together: one value per lab
# sample, averaged per species and tissue (perch, sampled in both
# programmes, gets one combined average, as in species.csv).
#
# Run from the project folder. Writes output/tools/biological_averages.csv
# next to the current values, and does not change species.csv unless
# `update_species` is TRUE. Missing averages keep their current values.

library(tidyverse)

update_species <- FALSE

out_dir <- here::here("output", "tools")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
species_file <- here::here("config", "harsat", "species.csv")
species_info <- read.csv(species_file, check.names = FALSE)

matrix_code <- c("Muscle" = "MU", "Liver" = "LI", "Soft tissue" = "SB", "Egg content" = "EH")

averages <- fmcom::fmcom |>
  filter(organ %in% names(matrix_code)) |>
  distinct(species, organ, sample_ID, fat_percentage, dry_weight_percentage) |>
  summarise(drywt = mean(dry_weight_percentage, na.rm = TRUE),
            lipidwt = mean(fat_percentage, na.rm = TRUE),
            n_samples = n(), .by = c(species, organ)) |>
  mutate(across(c(drywt, lipidwt), \(x) if_else(is.nan(x), NA_real_, round(x, 2))),
         matrix = matrix_code[as.character(organ)]) |>
  pivot_longer(c(drywt, lipidwt), names_to = "variable", values_to = "new") |>
  mutate(column = paste0(matrix, "_", variable))

current <- species_info |>
  select(species = reference_species, matches("_(drywt|lipidwt)$")) |>
  pivot_longer(-species, names_to = "column", values_to = "current")

comparison <- full_join(current, select(averages, species, column, new, n_samples),
                        by = c("species", "column")) |>
  filter(!is.na(current) | !is.na(new)) |>
  arrange(species, column)
write_csv(comparison, file.path(out_dir, "biological_averages.csv"), na = "")
message("Written to ", file.path(out_dir, "biological_averages.csv"), " (",
        n_distinct(comparison$species), " species)")

## Optionally update species.csv ----
if (update_species) {
  new_wide <- averages |>
    filter(species %in% species_info$reference_species, !is.na(new)) |>
    select(reference_species = species, column, new) |>
    pivot_wider(names_from = column, values_from = new)
  updated <- species_info
  for (col in intersect(names(new_wide)[-1], names(species_info))) {
    value <- new_wide[[col]][match(updated$reference_species, new_wide$reference_species)]
    updated[[col]] <- coalesce(value, updated[[col]])
  }
  write_csv(updated, species_file, na = "")
  message("Updated ", species_file)
}
