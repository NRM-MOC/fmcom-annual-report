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
# `loq_open` is TRUE. The x-axis ends at `report_year`, so a series that has
# stopped is visibly shorter, and covers at least `min_years` years.
ts_plot <- function(assessment, obs, labels, report_year, min_years = 10,
                    loq_colour = "#0072B2", loq_open = TRUE){

  obs_ind <- assessment$data |>
    # Column for values where condition is '<'
    dplyr::mutate(LOQ = as.numeric(ifelse(censoring == "<", concentration, NA)))

  obs_avg <- assessment$annualIndex |>
    dplyr::mutate(obs_avg = exp(index),
                  LOQ = as.numeric(ifelse(censoring == "<", obs_avg, NA)))

  if ("pred" %in% names(assessment)){
    pred <- assessment$pred |>
      dplyr::mutate(pred_conc = exp(fit), upper = exp(ci.upper), lower = exp(ci.lower))
  }

  if ('reference.values' %in% names(assessment)){
    EQS <- assessment$reference.values |>
      dplyr::mutate(threshold = exp(refvalue))
    EQS_e <- EQS$threshold[1]
  }

  loq_shape <- if (loq_open) 21 else 19   # 21: open circle with white fill
  x_range <- c(min(obs_ind$year, report_year - min_years + 1, na.rm = TRUE), report_year)

  # y-axis text and title
  basis <- dplyr::coalesce(lookup(obs$basis, basis_text), obs$basis)
  matrix <- dplyr::coalesce(lookup(obs$matrix, matrix_text), obs$matrix)
  y_axis <- paste(labels$determinand, obs$unit, basis, matrix)
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
    # Black for values above LOQ only, so no black point shows behind a <LOQ one
    ggplot2::geom_point(data = dplyr::filter(obs_ind, is.na(LOQ)), ggplot2::aes(x = year, y = concentration),
                        size = 0.75, color = 'black') +
    ggplot2::geom_point(data = obs_ind, ggplot2::aes(x = year, y = LOQ), size = 1,
                        color = loq_colour, shape = loq_shape, fill = "white") +
    ggplot2::geom_point(data = dplyr::filter(obs_avg, is.na(LOQ)), ggplot2::aes(x = year, y = obs_avg),
                        size = 2, color = 'black') +
    ggplot2::geom_point(data = obs_avg, ggplot2::aes(x = year, y = LOQ), size = 2,
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
