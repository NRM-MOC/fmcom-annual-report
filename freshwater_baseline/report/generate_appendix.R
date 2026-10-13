# This script generates a pdf appendix based on a list of MoCiS objects
#
library(MoCiS.tools) #devtools::install_github("NRM-MOC/MoCiS.tools")
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

## Change folder names for location of figures in rmd files before running the appendix

source("functions/functions.R")

contents <- read.csv("Contents_for_fcom_appendix_26_v2_SF.csv")

# Generates an Rmd
file_name <- "appendix_HARSAT_fcom26_v2_SF.Rmd"
appendix(contents, file_name)#, 
         #exclude_maps = c('AHCH','BHCH'))   # removed AHCH, BHCH as no data or most data <LOQ (Could remove all but pike/char for HBC & LINDAN,

                                            # BDE28 maybe remove perch maps but keep average map)

appendix(contents, file_name, 
         exclude_maps = c('AHCH','BHCH','LINDAN','CB28','PFHXA','PFHPA','LPFBS','LPFHXS',
                          'BPFHXS','PFHXS','LPFDS','BPFDS','PFDS'))   # removed AHCH, BHCH etc as no data or most data <LOQ 
                                            





#renders to pdf
rmarkdown::render(file_name)
