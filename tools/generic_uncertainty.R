#######################################################################v
# Calculating generic uncertainties for HARSAT determinand.csv file ####
#######################################################################v

library(tidyverse)
library(readxl)

## Read data from database ----
G_sd <- mcomDb::MCoM |>
  select(specimen_ID:uncertainty)      

## Create dataframe for contaminants without data < LOQ ----
## sd_constant as "LOD/3" of reported 2022 data
## mean_value (LOD) as mean(LOD) of reported 2022 data
## TEQ LOD is set equal to PECDF2
substance_group <- c(rep(c('Metals'),5),rep(c('PCBs'),12),rep(c('Dioxins and furans'),3),rep(c('PAH'),3))
contaminant     <- c('Hg','As','Cu','Se','Zn',
                 'CB77','CB81','CB126','CB169','CB105','CB114','CB118','CB123','CB156','CB157','CB167','CB189',
                 'TCDF','PECDF2','TEQDFP',
                 'FLU','CHR','BBF')
unit            <- c('ug/kg ww',(rep(c('ug/g dw'),4)),(rep(c('pg/kg'),12)),rep(c('ng/kg'),3),rep(c('ug/kg'),3))
mean_value      <-c(0.8,0.06,0.11,0.06,0.59,rep(c(0.23),4),rep(c(2.34),8),0.23,0.23,0.23,0.31,0.12,0.16)
extra           <- data.frame(substance_group,contaminant,unit,mean_value) |>
                   mutate(biota_sd_constant=mean_value/3)

## Sd_constant determined as LOD/3 (in some cases LOQ/3) ----
## for each contaminant across all years
sd_constant <- G_sd |>
  filter(LOQ_LOD == "<LOQ" | LOQ_LOD == "<LOD" | LOQ_LOD == "LOQ or <LOD") |>
  mutate(sd_constant = value/3) |>
  ### remove incorrect LOD values for two dioxins (should be corrected in dataset) ----
  filter(contaminant!='CB77') |> filter(contaminant!='CB189') |> filter(contaminant!='FLU') |>
  group_by(substance_group,contaminant,unit) |>
  summarize(biota_sd_constant = mean(sd_constant), mean_value= mean(value)) |>
  ungroup() |>
  bind_rows(extra)

## Create file with average LOD (LOQ) values ----
sd_constant_join <- sd_constant |>
  select(c(contaminant, mean_value)) 

## Sd_variable determined as the relative proportion of the ----
## uncertainty to the concentration (should be between 0.1-0.4)
sd_variable <- G_sd |>
  filter(!is.na(uncertainty)) |>
  filter( LOQ_LOD == ">LOQ" | LOQ_LOD == ">LOD") |> 
  ### filter X times LOD (LOQ) to only keep uncertainty for data well above LOQ observations ----
  left_join(sd_constant_join, by = 'contaminant') |>
  mutate(value = if_else(value < (mean_value*2), NA, value))|>
  drop_na(value) |>
  ### create % uncertainty value ----
  mutate(uncertainty_perc = uncertainty/value*100) |>
  group_by(substance_group,contaminant,unit) |>
  summarize(biota_sd_variable = mean(uncertainty_perc)/100) |>
  ungroup()

## Merge sd's ----
sd <- full_join(sd_variable,sd_constant,by=c('substance_group','contaminant')) |>
  select(-c('unit.x','unit.y','mean_value')) |>
  rename(determinand= 'contaminant') |>
  ### fill NAs with group averages ----
  group_by(substance_group) |>
  mutate(biota_sd_variable = case_when(
    is.na(biota_sd_variable) ~ mean(biota_sd_variable, na.rm=TRUE),
    TRUE ~as.numeric(biota_sd_variable)
  )) |>
  ungroup() |>
  mutate_all(.funs=toupper) |>
  mutate(    biota_sd_variable = as.numeric(biota_sd_variable),
             biota_sd_constant = as.numeric(biota_sd_constant)) |>
  select(-c('substance_group'))|>
  ### round to avoid error when reading into HARSAT ----
  mutate_if(is.numeric, round, digits = 5)

## Read determinand.csv file and add new info ----
determinand <- read.csv("information/determinand.csv") |>
  select(-c('biota_sd_variable','biota_sd_constant')) |>
  left_join(sd, by = 'determinand') |>
  select(c(determinand:water_auxiliary,biota_sd_constant,biota_sd_variable,sediment_sd_constant:good_status)) 

## Write database files to csv ----
write.csv(determinand,"information/determinand.csv",na="",row.names=FALSE)

