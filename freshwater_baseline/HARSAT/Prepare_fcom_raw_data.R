####################################v
# STEP1: Read in and massage NRM data  ----
####################################v

library(tidyverse)
library(readxl)
library(fcom) #devtools::install_local("<path-removed>/FCOM/database/fcomDb_260109", force = TRUE)

#############################################################################v
# Import data ----
### Imported data will be merged on "country", "station_code", "station_name" 

## Station information ----
stations <- read.csv("<path-removed>/MCOM/Yosrbase/Script and data/stations_SGU_NRM.csv") |>
  mutate(station_code_SGU = paste0('00',station_code_SGU)) |>
  select(station_code=nrm_code,station_code_SGU)
#stations <- read.csv("data/stations.csv") #%>% select(c('country','station_code','station_name','station_latitude','station_longitude','NRM_region'))
raw_data <- read_csv('../fcom26_rawdata/raw_data_fcom_2026_v2_SF.csv') |>
  mutate(station_code_SGU = paste0('00',station_code_SGU)) |>
  mutate(date = as.character(date))

#censoring <- NA

## Contaminant data ----
NRM <- fcom |>
  filter(!species=='Rutilus rutilus') |>
  bind_rows(raw_data) |> 
  mutate(fat_percentage = median(fat_percentage), .by = "sample_ID") |>
  #mutate(substance_group = if_else(substance_group=='PFASs','PFAS',substance_group)) |>
  # correct data format when day is missing
  #mutate(date = case_when(
  #  str_length(date) == 7 ~ paste(date,'01',sep='-'),
  #  TRUE ~ date)) |>
  #filter(substance_group=='Metals') |>
  ##filter(substance_group=='Pesticides' | substance_group=='Solvents' ) |>
  #filter(substance_group=='Pesticides and solvents' ) |>
  filter(substance_group=='PCBs'|substance_group=='Dioxins and furans') |>
  #filter(substance_group=='PFAS') |>
  #filter(substance_group=='BFRs') |>
  ##filter(substance_group=='PAH') |>
  ##filter(substance_group=='Organotin compounds') |>
  #filter(substance_group=='PCBs') |>
  #filter(substance_group=='Dioxins and furans') |>
  
  ### station names spring ----
  mutate(station_name = case_when(
  station_name== 'Angskarsklubb' & season =='Spring'~ 'Angskarsklubb_S',
  station_name== 'Utlangan' & season =='Spring'~ 'Utlangan_S',
  TRUE ~ station_name)) |>
  left_join(stations, by = 'station_code_SGU') |>
  rename(n_individual = 'number_individuals',sample='sample_ID', matrix ='organ') |>
  ### new names sex and matrix ----
mutate(sex = if_else(sex == 'Female', 'F', if_else(sex=='Male', 'M','X'))) |>
mutate(matrix = case_when(
  matrix == 'Liver' ~'LI',
  matrix == 'Muscle' ~ 'MU',
  matrix == 'Soft tissue' ~ 'SB',
  matrix == 'Egg content' ~ 'EH',
  TRUE ~ matrix)) |>
  ### basis for all 6 possible units ----
mutate(basis = case_when(
  unit == 'ug.g-1.dw-1' ~ 'D', 
  unit == 'ng.g-1.dw-1' ~ 'D',
  unit == 'ng.g-1.ww-1' ~ 'W',
  unit == 'ng.g-1.lw-1' ~ 'L',
  unit == 'pg.g-1.lw-1' ~ 'L',
  unit == 'ug.g-1.lw-1' ~ 'L')) |>
  ### rename units for all 6 possible units ----
mutate(unit = case_when(
  unit == 'ug.g-1.dw-1' ~ 'ug/g', 
  unit == 'ng.g-1.dw-1' ~ 'ng/g',
  unit == 'ng.g-1.ww-1' ~ 'ng/g',
  unit == 'ng.g-1.lw-1' ~ 'ng/g',
  unit == 'pg.g-1.lw-1' ~ 'pg/g',
  unit == 'ug.g-1.lw-1' ~ 'ug/g')) |>
  #mutate(unit_uncertainty = unit) |>  # ? SD, U2????
  ### censoring for all 5 possible combinations ----
#add_column(censoring = NA) |>
mutate(censoring = '',
  censoring = case_when(
  LOQ_LOD == '<LOQ' ~ 'Q',
  LOQ_LOD == '<LOD' ~ 'D',
  LOQ_LOD == '<LOQ or <LOD' ~ 'Q',
  LOQ_LOD == '>LOD, <LOQ' ~ 'Q',
  is_censored == TRUE & year == 2024 ~ 'Q',
  TRUE ~ censoring
  )) |>
  ### creating % uncertainty value ----
mutate(uncertainty = as.numeric(uncertainty),
  uncertainty = uncertainty/value*100, # keep as is, unit "sd"
  unit_uncertainty = '%',
  unit_uncertainty = if_else(is.na(uncertainty), '', unit_uncertainty)
  ) |>
mutate(country='Sweden') |>
  ### merge PCB138 and PCB163 ----
mutate(contaminant = if_else(contaminant == 'CB138and163','CB138',contaminant))
  ### obsolete - merging PCB-118 from the two labs
 #mutate(contaminant= if_else(contaminant == 'CB118_ndl','CB118',contaminant))


variables <- c('country','station_code','station_name','year','date','species','n_individual','sample','determinand','matrix','unit','value','basis') # 'sex' (no required)
extra_variables <- c('censoring','uncertainty','unit_uncertainty')
all_variables <- c(variables,extra_variables)

## Add dry weight and fat % to long format ----
### Dry weight ----
NRM_dw <- NRM |> drop_na(dry_weight_percentage) |> select(-c(value))  |> rename(value='dry_weight_percentage') |> mutate(determinand='DRYWT%',unit='%') |>
  mutate(basis='W') |> select(all_of(variables)) |>
  unique()
### Wet weight ----
# basis set to "W" as this avoids warnings but I don't know what that means in terms of calculations - ask Rob
NRM_lw <- NRM |> drop_na(fat_percentage) |> select(-c(value))  |> rename(value='fat_percentage') |> mutate(determinand='LIPIDWT%',unit='%') |>
  mutate(basis='W') |> select(all_of(variables)) |>
  unique()

### Length ----
# basis set to "W" as this avoids warnings but I don't know what that means in terms of calculations - ask Rob
NRM_le <- NRM |> drop_na(total_length) |> select(-c(value))  |> rename(value='total_length') |> mutate(determinand='LNMEA',unit='cm') |>
  mutate(basis='') |>
  mutate(matrix = case_when(
    matrix == 'LI' ~ 'WO',
    matrix == 'MU' ~ 'WO', 
    matrix == 'SB' ~ 'SH',
    matrix == 'EH' ~ 'ES')) |> 
  select(all_of(variables)) |>
  unique()

### Weight ----
# basis set to "W" as this avoids warnings but I don't know what that means in terms of calculations - ask Rob
NRM_we <- NRM |> drop_na(weight) |> select(-c(value))  |> rename(value='weight') |> mutate(determinand='WTMEA',unit='g') |>
  mutate(basis='W') |>
  mutate(matrix = case_when(
    matrix == 'LI' ~ 'WO',
    matrix == 'MU' ~ 'WO', 
    matrix == 'SB' ~ 'SH',
    matrix == 'EH' ~ 'ES')) |>
  select(all_of(variables)) |>
  unique()

### Age ----
# basis set to NA, for variables without age, rows are removed
NRM_ag <- NRM |> drop_na(age) |> select(-c(value))  |> rename(value='age') |> mutate(determinand='AGMEA',unit='y') |>
  mutate(basis='',
    matrix = case_when(
    matrix == 'LI' ~ 'WO',
    matrix == 'MU' ~ 'WO', 
    matrix == 'SB' ~ 'SH',
    matrix == 'EH' ~ 'ES')) |>
  filter(value != 0) |>
  select(all_of(variables)) |>
  unique()

### Bind to long format----
## Select variables for HARSAT run ----
NRM_all_select <- NRM |>   rename(determinand='contaminant') |>
  select(all_of(all_variables)) |>
  bind_rows(NRM_dw, NRM_lw, NRM_le, NRM_we, NRM_ag) #|> filter(determinand =='Hg'|determinand =='LNMEA'|determinand =='WTMEA'|determinand =='AGMEA')
  #rename(uncertainty_unit='unit_uncertainty', uncer ='uncertainty')


#NRM_all_select <- NRM_all |> select(c(country,station_code, station_name,year,date,species,n_individual,
#                                      sample,determinand,matrix,unit,value,basis))#, uncertainty, uncertainty_unit))

write.csv(NRM_all_select,"data/NRM_PCB_PCDDF_2026_SF.csv",na="",row.names=FALSE)
#write.csv(NRM_all_select,"data/NRM_metals_2026_SF.csv",na="",row.names=FALSE)
#write.csv(NRM_all_select,"data/NRM_BFR_2026_SF.csv",na="",row.names=FALSE)
#write.csv(NRM_all_select,"data/NRM_pes_sol_2026_SF.csv",na="",row.names=FALSE)
#write.csv(NRM_all_select,"data/NRM_pfas_2026_SF.csv",na="",row.names=FALSE)
#write.csv(NRM_all_select,"data/NRM_PCDDF_2026_SF.csv",na="",row.names=FALSE)
#write.csv(NRM_all_select,"data/NRM_PCB_2026_SF.csv",na="",row.names=FALSE)
