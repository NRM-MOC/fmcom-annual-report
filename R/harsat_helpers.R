####################################################-
# Function to set the basis (W, D, L) for each ----
# contaminants group and (for metals) contaminants
# according to NRM evaluation needs.
# Supplement the get_basis_X functions located
# in "information_functions.R" of HARSAT
####################################################-

get_basis_nrm <- function(data, info) {

  # Wet weight is set as the default

  basis_id <- switch(
    info$compartment,
    biota = "W"
  )

  # data$group: all contaminant groups - Metals, Organobromines, Organofluorines,
  #     Chlorobiphenyls, Dioxins, PAH_parent, Organotins, Chlorinated pesticides

  new_basis <- dplyr::case_when(
    data$group %in% c("Metals") & data$determinand %in% c("HG") ~ "W",
    data$group %in% c("Metals") & !data$determinand %in% c("HG") ~ "D",
    data$group %in% c("Organofluorines") ~ "W",
    data$group %in% c("Organobromines") ~ "L",
    data$group %in% c("Chlorobiphenyls") ~ "L",
    data$group %in% c("Dioxins") ~ "L",
    data$group %in% c("PAH_parent") ~ "D",
    data$group %in% c("Chlorinated pesticides") ~ "L",
    data$group %in% c("Organotins") ~ "W",
    TRUE ~ basis_id
  )

  new_basis
}


####################################################-
# Function to plot figures ----
####################################################-

basis_text <- c(W = "ww", D = "dw", L = "lw")
matrix_text <- c(MU = "muscle", LI = "liver", SB = "soft body", EH = "egg content")

# Time series plot for one assessed series. `labels` gives the display names:
# determinand, station and species (from the lookup tables). Values above LOQ
# are black; values below LOQ use `loq_colour`, as open circles if
# `loq_open` is TRUE. All years with data are shown: HARSAT leaves some years
# out of the trend fit (before a gap in sampling, early years mostly below
# LOQ, or years dropped to make the model converge), and those are drawn in
# `excluded_colour`. The x-axis ends at `report_year`, so a series that has
# stopped is visibly shorter, and covers at least `min_years` years.
# `distribution`: HARSAT models lognormal series (contaminants) on the log
# scale, normal series (biological variables) on the original scale.
ts_plot <- function(assessment, obs, labels, report_year, min_years = 10,
                    distribution = "lognormal",
                    loq_colour = "#0072B2", loq_open = TRUE,
                    excluded_colour = "grey65"){

  # Annual means, trend and thresholds back on the scale of the data
  back <- if (identical(distribution, "normal")) identity else exp

  # Years HARSAT used in the trend fit; all observations come from fullData
  fit_years <- unique(assessment$data$year)
  obs_ind <- (assessment$fullData %||% assessment$data) |>
    # Column for values where condition is '<'
    dplyr::mutate(LOQ = as.numeric(ifelse(censoring == "<", concentration, NA)),
                  in_fit = year %in% fit_years)

  obs_avg <- assessment$annualIndex |>
    dplyr::mutate(obs_avg = back(index),
                  LOQ = as.numeric(ifelse(censoring == "<", obs_avg, NA)),
                  in_fit = year %in% fit_years)
  fit_ind <- dplyr::filter(obs_ind, in_fit)
  fit_avg <- dplyr::filter(obs_avg, in_fit)
  out_ind <- dplyr::filter(obs_ind, !in_fit)
  out_avg <- dplyr::filter(obs_avg, !in_fit)

  if ("pred" %in% names(assessment)){
    pred <- assessment$pred |>
      dplyr::mutate(pred_conc = back(fit), upper = back(ci.upper), lower = back(ci.lower))
  }

  if ('reference.values' %in% names(assessment)){
    EQS <- assessment$reference.values |>
      dplyr::mutate(threshold = back(refvalue))
    EQS_e <- EQS$threshold[1]
  }

  loq_shape <- if (loq_open) 21 else 19   # 21: open circle with white fill
  x_range <- c(min(obs_ind$year, report_year - min_years + 1, na.rm = TRUE), report_year)

  # y-axis text and title
  basis <- dplyr::coalesce(lookup(obs$basis, basis_text), obs$basis)
  matrix <- dplyr::coalesce(lookup(obs$matrix, matrix_text), obs$matrix)
  y_axis <- labels$y_axis %||% paste(labels$determinand, obs$unit, basis, matrix)
  title <- paste(labels$station, labels$species, sep = ' - ')

  ggplot2::ggplot() +
    {
      if ('reference.values' %in% names(assessment)){
        list(
          ggplot2::geom_hline(yintercept = EQS_e, linetype = 'dashed'),
          # Coloured area below the threshold
          ggplot2::geom_ribbon(data = obs_avg, ggplot2::aes(x = year, ymin = 0, ymax = pmin(EQS_e, max(obs_avg*1.5, na.rm = TRUE))),
                               fill = "lightgreen", alpha = 0.3)
        )
      }
    } +
    # Fitted trend and confidence band, if a model was fitted; drawn before the
    # points so the band does not grey the points inside it
    {
      if (!is.null(assessment$pred)){
        list(
          ggplot2::geom_ribbon(data = pred, ggplot2::aes(x = year, ymax = upper, ymin = lower), fill = "black", alpha = 0.25),
          ggplot2::geom_line(data = pred, ggplot2::aes(x = year, y = pred_conc), alpha = .1, linetype = 'solid', color = 'black')
        )
      }
    } +
    # Years left out of the trend fit, in grey (filled above LOQ, open below)
    ggplot2::geom_point(data = dplyr::filter(out_ind, is.na(LOQ)), ggplot2::aes(x = year, y = concentration),
                        size = 0.75, color = excluded_colour) +
    ggplot2::geom_point(data = out_ind, ggplot2::aes(x = year, y = LOQ), size = 1,
                        color = excluded_colour, shape = loq_shape, fill = "white") +
    ggplot2::geom_point(data = dplyr::filter(out_avg, is.na(LOQ)), ggplot2::aes(x = year, y = obs_avg),
                        size = 2, color = excluded_colour) +
    ggplot2::geom_point(data = out_avg, ggplot2::aes(x = year, y = LOQ), size = 2,
                        color = excluded_colour, shape = loq_shape, fill = "white") +
    # Black for values above LOQ only, so no black point shows behind a <LOQ one
    ggplot2::geom_point(data = dplyr::filter(fit_ind, is.na(LOQ)), ggplot2::aes(x = year, y = concentration),
                        size = 0.75, color = 'black') +
    ggplot2::geom_point(data = fit_ind, ggplot2::aes(x = year, y = LOQ), size = 1,
                        color = loq_colour, shape = loq_shape, fill = "white") +
    ggplot2::geom_point(data = dplyr::filter(fit_avg, is.na(LOQ)), ggplot2::aes(x = year, y = obs_avg),
                        size = 2, color = 'black') +
    ggplot2::geom_point(data = fit_avg, ggplot2::aes(x = year, y = LOQ), size = 2,
                        color = loq_colour, shape = loq_shape, fill = "white") +
    ggplot2::ylab(y_axis) +
    ggplot2::ggtitle(title) +
    ggplot2::theme_classic() +
    ggplot2::theme(text = ggplot2::element_text(size = 15),
                   axis.text.x = ggplot2::element_text(color = "black"),
                   axis.text.y = ggplot2::element_text(color = "black")) +
    # Whole years only on the x-axis, always including the report year
    ggplot2::scale_x_continuous(breaks = function(limits) year_breaks(limits, report_year)) +
    # y-axis from 0 to 1.5 x the highest annual mean. coord_cartesian() crops
    # the view; scale limits would drop the parts of the confidence band (and
    # any points) above the axis, leaving gaps in the band
    ggplot2::coord_cartesian(xlim = x_range,
                             ylim = c(0, max(obs_avg$obs_avg*1.5, na.rm = TRUE)))
}

# Whole-year axis breaks that always include the report year. A break one
# year from it, or closer than half the break spacing, is dropped so the
# labels don't crowd (the axis covers at least 10 years).
year_breaks <- function(limits, report_year) {
  breaks <- pretty(limits)
  breaks <- breaks[breaks == round(breaks)]
  step <- if (length(breaks) > 1) min(diff(breaks)) else 1
  distance <- abs(breaks - report_year)
  breaks <- breaks[!(distance <= 1 | distance < step / 2) | breaks == report_year]
  sort(unique(c(breaks, report_year)))
}
