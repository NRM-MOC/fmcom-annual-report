# This script generates a pdf appendix based on a list of MoCiS objects
#
library(MoCiS.tools)
library(tidyverse)
library(readxl)
library(knitr)
library(rnaturalearth)
library(rnaturalearthdata)
library(sf)
library(cowplot)
library(ggspatial)
library(scales)
library(kableExtra)

source("functions/functions.R")

contents <- read.csv("contents_for_HARSAT.csv")

# Generates an Rmd
file_name <- "appendix_HARSAT_25_v4_test.Rmd"
appendix(contents, file_name, 
         exclude_maps = c("CR", "AHCH", "LINDAN", "PFHXA", "PFHPA", "LPFBS", "LPFDS", "PFDS"))
#renders to pdf
rmarkdown::render(file_name)
