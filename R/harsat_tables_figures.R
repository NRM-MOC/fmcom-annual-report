# Step 2c: tables and figures from the HARSAT assessments ----
#
# Same output as the old Report_MCOM_results.R / Report_fcom_results.R, with
# names from the lookup tables (config/lookups/, fmcom master stations) and
# settings from config/<programme>.yml.

## Display names ----
load_lookup <- function(name) {
  utils::read.csv(here::here("config", "lookups", paste0(name, ".csv")), encoding = "UTF-8")
}

# Station names from the fmcom master table, plus " spring" for the spring
# stations (e.g. Angskarsklubb_S)
station_display_names <- function(cfg, master_stations) {
  load_harsat_stations(cfg) |>
    dplyr::left_join(dplyr::select(master_stations, station_code_SGU, station),
                     by = "station_code_SGU") |>
    dplyr::transmute(station_code,
                     station_display = dplyr::if_else(season %in% "Spring",
                                                      paste(station, "spring"), station))
}

report_names <- function(cfg) {
  list(determinands = load_lookup("determinands"),
       species = load_lookup("species"),
       stations = station_display_names(cfg, load_master_tables()$stations))
}

assessment_file <- function(cfg, group) {
  file.path(harsat_dir(cfg, "assessments"), paste0(group, ".rds"))
}

## Summary table ----
# HARSAT's summary table per group (summaries/<group>.csv), combined into
# biota_summary.csv for all groups assessed so far
write_harsat_summaries <- function(cfg, groups) {
  dir <- harsat_dir(cfg, "summaries")
  for (group in groups) {
    harsat_groups <- unlist(cfg$harsat$groups[[group]]$harsat)
    harsat::write_summary_table(
      readRDS(assessment_file(cfg, group)),
      output_file = paste0(group, ".csv"),
      output_dir = dir,
      determinandGroups = list(levels = harsat_groups, labels = harsat_groups),
      extra_output = "power"
    )
  }
  files <- file.path(dir, paste0(names(cfg$harsat$groups), ".csv"))
  summary <- lapply(files[file.exists(files)], utils::read.csv, colClasses = "character") |>
    dplyr::bind_rows() |>
    readr::type_convert(col_types = readr::cols())
  utils::write.csv(summary, file.path(harsat_dir(cfg), "biota_summary.csv"),
                   row.names = FALSE, na = "")
  summary
}

## Time series plots ----
# One PDF per series: figs/<station code>_<species code>_<determinand>.pdf
plot_timeseries <- function(cfg, groups, lookups) {
  dir <- harsat_dir(cfg, "figs")
  files <- character()
  for (group in groups) {
    a <- readRDS(assessment_file(cfg, group))
    for (series in names(a$assessment)) {
      if (is.null(a$assessment[[series]])) next
      obs <- a$timeSeries[series, ]
      labels <- list(
        determinand = display_name(obs$determinand, lookups$determinands, "determinand", "name"),
        station = display_name(obs$station_code, lookups$stations, "station_code", "station_display"),
        species = display_name(obs$species, lookups$species, "species", "name")
      )
      code <- display_name(obs$species, lookups$species, "species", "code")
      file <- paste0(paste(obs$station_code, code, obs$determinand, sep = "_"), ".pdf")
      plot <- ts_plot(a$assessment[[series]], obs, labels, report_year = cfg$year,
                      min_years = cfg$tables_figures$plot_min_years)
      ggplot2::ggsave(file.path(dir, file), plot, width = 6, height = 6, dpi = 300)
      files <- c(files, file)
    }
  }
  # Two series sharing a file name (e.g. same substance in two tissues)
  # would overwrite each other
  unique(files[duplicated(files)])
}

# Name from a lookup table, or the code itself if it is not in the table
display_name <- function(code, table, from, to) {
  dplyr::coalesce(table[[to]][match(code, table[[from]])], code)
}

## Tables per substance and species group ----
summary_table_rows <- function(summary, lookups, station_order) {
  rows <- summary |>
    dplyr::mutate(
      years = paste(first_year_all, last_year, sep = "-"),
      dplyr::across(c(p_linear_trend, p_nonlinear_trend, p_overall_trend,
                      p_overall_change, p_recent_change, EQS_value), ~ round(.x, 3)),
      dplyr::across(c(mean_last_year, climit_last_year), ~ round(.x, 4)),
      Station = display_name(station_code, lookups$stations, "station_code", "station_display")
    ) |>
    dplyr::select(Cont_short = determinand, station_code, Station, Species = species,
                  Latitude = station_latitude, Longitude = station_longitude,
                  "n year all" = n_year_all, "n year fit" = n_year_fit, years,
                  "p nonlinear trend" = p_nonlinear_trend, "p linear trend" = p_linear_trend,
                  "p overall trend" = p_overall_trend, "overall change" = overall_change,
                  "p overall change" = p_overall_change, "detectable trend" = detectable_trend,
                  "recent change" = recent_change, "p recent change" = p_recent_change,
                  "mean last year" = mean_last_year, "climit last year" = climit_last_year,
                  threshold = EQS_value)
  order_value <- station_order_value(rows$Latitude, rows$Longitude, station_order)
  rows |>
    dplyr::mutate(Station = forcats::fct_reorder(Station, order_value)) |>
    dplyr::arrange(dplyr::desc(Station))
}

# Sorts stations in report order, highest value first (station_order in the
# config). "coast": east coast north to south, then the west coast south to
# north; "latitude": north to south.
station_order_value <- function(latitude, longitude, station_order) {
  switch(station_order,
    coast = -(-1)^(longitude > 13.6) * latitude,
    latitude = latitude)
}

# HARSAT station codes in report order, as in the tables (used to order the
# time series plots in the report)
report_station_order <- function(cfg) {
  s <- load_harsat_stations(cfg)
  value <- station_order_value(s$station_latitude, s$station_longitude,
                               cfg$tables_figures$station_order)
  s$station_code[order(-value, s$station_code)]
}

write_summary_tables <- function(cfg, rows) {
  dir <- harsat_dir(cfg, "tables")
  for (table_group in names(cfg$tables_figures$table_groups)) {
    species <- unlist(cfg$tables_figures$table_groups[[table_group]])
    group_rows <- dplyr::filter(rows, Species %in% species) |>
      dplyr::select(-station_code, -Latitude, -Longitude)
    for (det in unique(group_rows$Cont_short)) {
      utils::write.csv(dplyr::select(dplyr::filter(group_rows, Cont_short == det), -Cont_short),
                       file.path(dir, paste0(det, "_", table_group, "_table.csv")),
                       row.names = FALSE)
    }
  }
}

## Mean and trend maps ----
# For the map species: fitted mean in the last year (red outline above the
# threshold) and the recent yearly change, as a map and a bar chart
plot_maps <- function(cfg, rows) {
  dir <- harsat_dir(cfg, "figs")
  world_map <- rnaturalearth::ne_countries(scale = "medium", returnclass = "sf") |>
    sf::st_crop(c(xmin = 8, xmax = 25, ymin = 54, ymax = 70))
  # Spring series are left out of the map panel: they share coordinates with
  # the autumn series and would overlap them and nearby stations. They are
  # kept in the bar chart.
  stations <- load_harsat_stations(cfg)
  spring <- stations$station_code[stations$season %in% "Spring"]
  mf <- rows |>
    dplyr::filter(Species == cfg$tables_figures$map_species) |>
    dplyr::select(Cont_short, station_code, Station, Longitude, Latitude, threshold,
                  recent_change = `recent change`, mean_last_year = `mean last year`)
  cont <- dplyr::distinct(mf, Cont_short, threshold)

  for (idx in seq_len(nrow(cont))) {
    sub_data <- dplyr::filter(mf, Cont_short == cont$Cont_short[idx])
    threshold <- cont$threshold[idx]
    sub_data$above <- ifelse(sub_data$mean_last_year < threshold | is.na(threshold), "black", "red")
    map_data <- dplyr::filter(sub_data, !station_code %in% spring)
    # Same colour range in both panels, from all stations
    mean_limits <- value_range(sub_data$mean_last_year)
    change_limits <- value_range(sub_data$recent_change)

    mean_map <- cowplot::plot_grid(
      base_map(world_map) +
        ggplot2::geom_point(data = map_data,
                            ggplot2::aes(x = Longitude, y = Latitude, fill = mean_last_year, color = above),
                            alpha = .8, size = 5, shape = 21, stroke = 1) +
        ggplot2::scale_color_manual(values = c("red" = "red", "black" = "black")) +
        mean_fill(mean_limits),
      bar_chart(sub_data, "mean_last_year", paste("fitted mean", cfg$year)) + mean_fill(mean_limits)
    )
    ggplot2::ggsave(file.path(dir, paste0(cont$Cont_short[idx], "_mean_map.pdf")), mean_map,
                    width = 8, height = 5)

    rate_map <- cowplot::plot_grid(
      base_map(world_map) +
        ggplot2::geom_point(data = map_data,
                            ggplot2::aes(x = Longitude, y = Latitude, fill = recent_change),
                            alpha = .8, size = 5, shape = 21, stroke = 1) +
        change_fill(change_limits),
      bar_chart(sub_data, "recent_change", "yearly relative change, %") + change_fill(change_limits)
    )
    ggplot2::ggsave(file.path(dir, paste0(cont$Cont_short[idx], "_rate_map.pdf")), rate_map,
                    width = 8, height = 5)
  }
}

base_map <- function(world_map) {
  ggplot2::ggplot(world_map) +
    ggplot2::geom_sf(color = "white", fill = "grey") +
    ggspatial::annotation_north_arrow(location = "tl", height = ggplot2::unit(0.7, "cm"),
                                      width = ggplot2::unit(0.7, "cm")) +
    ggspatial::annotation_scale() +
    ggplot2::coord_sf(xlim = c(8, 25), ylim = c(54, 70), expand = FALSE) +
    ggplot2::theme_minimal() +
    ggplot2::theme(legend.position = "none") +
    ggplot2::ylab("Latitude") + ggplot2::xlab("Longitude")
}

bar_chart <- function(data, column, y_label) {
  ggplot2::ggplot(data, ggplot2::aes(x = Station, y = .data[[column]])) +
    ggplot2::geom_col(ggplot2::aes(fill = .data[[column]]), width = .6, color = "black",
                      linewidth = .5) +
    ggplot2::theme_minimal() +
    ggplot2::coord_flip() + ggplot2::xlab("") + ggplot2::ylab(y_label) +
    ggplot2::theme(legend.position = "none", axis.text.x = ggplot2::element_text(angle = 45))
}

# Range of the values, or NULL (the scale's default) if there are none
value_range <- function(x) if (any(!is.na(x))) range(x, na.rm = TRUE) else NULL

mean_fill <- function(limits) {
  ggplot2::scale_fill_continuous(high = "#132B43", low = "#56B1F7", limits = limits)
}

change_fill <- function(limits) {
  ggplot2::scale_fill_gradient2(high = scales::muted("red"), mid = "white",
                                low = scales::muted("blue"), limits = limits)
}

## Contents of the appendix ----
# One row per species and substance assessed, with the substance's name,
# report group and order (config/lookups/determinands.csv). Substances not in
# the lookup table are returned as `missing` (they would not be in the report).
appendix_contents <- function(summary, lookups) {
  assessed <- dplyr::distinct(summary, species, determinand)
  contents <- assessed |>
    dplyr::inner_join(dplyr::select(lookups$species, species, gen = code), by = "species") |>
    dplyr::inner_join(lookups$determinands, by = "determinand") |>
    dplyr::mutate(species_order = match(gen, lookups$species$code)) |>
    dplyr::arrange(group_order, var_order, species_order) |>
    dplyr::select(gen, var = determinand, var_name = name, group = report_group,
                  group_order, var_order)
  list(contents = contents,
       missing = setdiff(assessed$determinand, lookups$determinands$determinand))
}
