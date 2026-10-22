# Step 3: report appendix ----
#
# Writes the appendix .Rmd from the templates in 03_report/rmd/: the header,
# then one chapter per substance group, one section per substance, and per
# substance one part per species group (CLUP, FISH, MUSSEL, EGG templates).

report_template <- function(file) here::here("03_report", "rmd", file)

# Values for the {{...}} fields in header.Rmd, from config/<programme>.yml
appendix_header_values <- function(cfg) {
  r <- cfg$report
  # Stations sampled in both seasons, with names from the fmcom master table
  stations <- load_harsat_stations(cfg)
  spring_ids <- stations$station_code_SGU[stations$season %in% "Spring"]
  master <- load_master_tables()$stations
  spring <- master$station[match(spring_ids, master$station_code_SGU)]
  title <- gsub("{year}", cfg$year, r$title, fixed = TRUE)
  list(
    title = title,
    citation = paste0(r$citation$authors, " (", r$citation$year, "). ", title, ", ",
                      r$citation$publisher, "."),
    authors = paste0("- ", unlist(r$authors), collapse = "\n"),
    preamble = here::here("03_report", "preamble-latex.tex"),
    bibliography = here::here("03_report", "references.bib"),
    text_file = here::here(r$text_file),
    biota = r$biota,
    spring_note = if (length(spring) > 0) {
      paste0("For sampling sites with data collection in both spring and autumn (",
             paste(unique(spring), collapse = " and "),
             "), only the autumn series is shown on the map; both are included in the barplot. ")
    } else ""
  )
}

appendix_section <- function(section_contents){
  var <- section_contents$var[1]
  var_name <- section_contents$var_name[1]
  maps <- section_contents$maps[1]
  cat(paste("\n\n##", var_name, "\n\n"))
  if (sum(section_contents$gen == "CLUP") > 0){
    knitr::knit_expand(file = report_template("CLUPsection.Rmd")) |> cat(sep = "\n")
  }
  if (sum(section_contents$gen %in% c("GADU", "ZOAR", "PERC")) > 0){
    knitr::knit_expand(file = report_template("FISHsection.Rmd")) |> cat(sep = "\n")
  }
  if (sum(section_contents$gen == "MYTI") > 0){
    knitr::knit_expand(file = report_template("MUSSELsection.Rmd")) |> cat(sep = "\n")
  }
  if (sum(section_contents$gen %in% c("SIGR", "HAEM", "STER")) > 0){
    knitr::knit_expand(file = report_template("EGGsection.Rmd")) |> cat(sep = "\n")
  }
}

appendix_chapter <- function(chapter_contents){
  contents <- split(chapter_contents, chapter_contents$var_order)
  cat(paste("\n\n#", chapter_contents$group[1], "\n\n"))
  purrr::map(contents, appendix_section)
}

# `header_values`: values for the {{...}} fields in header.Rmd (title,
# authors, file paths, programme wording)
appendix <- function(contents, file_name, exclude_maps = NULL, header_values = list()){
  contents <- dplyr::mutate(contents, maps = !(var %in% exclude_maps)) |>
    split(contents$group_order)
  con <- file(file_name, open = "wt", encoding = "UTF-8")
  sink(con)
  on.exit({ sink(); close(con) })
  do.call(knitr::knit_expand, c(list(file = report_template("header.Rmd")), header_values)) |>
    cat(sep = "\n")
  purrr::map(contents, appendix_chapter)
  cat("\n\n# References\n\n")
}
