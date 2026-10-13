######################v
# biology averages ----
######################v

# Create biological averages for the information file "species"

library(tidyverse)

AVG <- mcomDb::MCoM |>
  select(species, organ, specimen_ID,fat_percentage,dry_weight_percentage) |>
  distinct() |> select(!specimen_ID) |>
  group_by(species, organ) |>
  summarise_all(mean, na.rm=TRUE)