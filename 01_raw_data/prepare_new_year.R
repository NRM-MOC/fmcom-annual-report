# Prepare raw analysis data ----

library(tidyverse)
library(readxl)
library(MoCiS2) # devtools::install_github("NRM-MOC/MoCiS2") #detach("package:MoCiS2", unload = TRUE)

################################################################-
## Read data ----
station_table <- read_excel("stations.xlsx") |> select(c(station_SGU,station_MCoM))

# OBS - new file to replace this "contaminant_SGU_NRM.csv"
cont <- read_delim("contaminant_SGU_NRM.csv",delim=';') |>
  filter(contaminant != 'CB118_ndl', SGU_Label != 'Dioktyltenn-jon') |>
  select(contaminant, NRM_PARAMETERKOD, contaminant_full_name, substance_group) |>
  na.omit()


path <- '../../../Radata/Radata/HAV/marina rapporten/2024/final/'



## Clean biology data ----
# Cleans table of biodata to extract columns: PROV_KOD_ORIGINAL PROVTAG_DAT TOTV TOTL   ALDR ANTAL_DAGAR KON
biodata <- read_excel("../esbase/Marina_lokal_251027_v2.xlsx", guess_max = 100000) %>% 
  select(PROV_KOD_ORIGINAL = ACCNR_ESBASE, PROVTAG_DAT = DATE, PROVTAG_DAT2 = DATE, Katalog = SPECIES, Kon = SEX, 
         TOTV, TOTL, ALDR) %>% 
  # Date unavailable for the following - taken middle of period of fishin (Holmöarna, strömming)
  #mutate(PROVTAG_DAT = ifelse(PROV_KOD_ORIGINAL %in% paste0("B2023/0", 9915:9938),"2023-10-15",PROVTAG_DAT)) |>
  mutate(PROVTAG_DAT2 = as.Date(PROVTAG_DAT2),
         PROVTAG_DAT = as.Date(PROVTAG_DAT),
         ANTAL_DAGAR = 1,
         KON = case_when(Katalog == "Sterna hirundo" ~ "Immature",
                         Katalog == "Uria aalge" ~ "Immature",
                         Katalog == "Haematopus ostralegus" ~ "Immature",
                         Katalog == "Mytilus edulis" ~ "Hermaphrodite",
                         Kon == "male" ~ "Male",
                         Kon == "female" ~ "Female",
                         Kon == "Hane" ~ "Male",
                         Kon == "Hona" ~ "Female",
                         Kon == "1" ~ "Male",
                         Kon == "2" ~ "Female",
                         Kon == 'X' ~ 'Mixed'),
         TOTV = as.numeric(TOTV),
         TOTL = as.numeric(TOTL),
         ALDR = as.numeric(ALDR)) |>
  # OBS!!! addition as mussels and bird eggs are reported in mm in the biologi_data file and not cm
  mutate(TOTL = case_when(
    Katalog == "Mytilus edulis" | Katalog == 'Uria aalge' | Katalog == 'Sterna hirundo' | Katalog == 'Haematopus ostralegus' ~ TOTL/10,
    TRUE ~ TOTL
  ))%>%
  select(-Katalog, -Kon, -PROVTAG_DAT2)

## Order current year data with Mocis2 ----
## Take notice of fixes specific for 2021 data for dry weight and fat weigh
## If these changes are permanent they should be added to MoCiS2
sia <- moc_read_lab(paste(path,"SI_Marin 2023.xlsm",sep=''), negative_for_nondetect = FALSE) |> 
  mutate(UTFOR_LABB = if_else(NRM_PARAMETERKOD =='TPRCI','EJ_REL',if_else(NRM_PARAMETERKOD == 'MTPRCI','EJ_REL',UTFOR_LABB))) |>
  select(PROV_KOD_ORIGINAL,NRM_PARAMETERKOD,MATVARDETAL) |>
  pivot_wider(names_from=NRM_PARAMETERKOD, values_from=MATVARDETAL) |> select(-c(TPRCI,MTPRCI))
metaller <- moc_read_lab(paste(path,"Metals_Marin_2024_250930.xlsm",sep='')) %>% filter(NRM_PARAMETERKOD != 'TPRC') 
bromerade <- moc_read_lab(paste(path,"BFRs_Marin_2024_SLV20251008.xlsm",sep='')) %>% #filter(NRM_PARAMETERKOD != 'FPRC') %>%
  mutate(ANALYS_MET = if_else(ORGAN == 'AGG', 'SLV_m064_f4',ANALYS_MET))
dioxiner <- moc_read_lab(paste(path,"Dioxins_Marin_2024_NRM.xlsm",sep=''))
hg <- moc_read_lab(paste(path,"HG_Marin_2024_250929.xlsm",sep='')) |> #%>% filter(NRM_PARAMETERKOD != 'TPRCI' & NRM_PARAMETERKOD !='MTPRCI')
  left_join(sia, by='PROV_KOD_ORIGINAL')
pah <- moc_read_lab(paste(path,"PAHs_Marin_2024_IVL.xlsm",sep=''))
pfas <- moc_read_lab(paste(path,"PFASs_Marin_2024_addedcomp.xlsm",sep='')) 


analysdata <- bind_rows(
  metaller, 
  bromerade, 
  dioxiner, 
  hg, 
  pah, 
  pfas#, 
  #sia
  ) |>
  mutate(PROVPLATS_ANALYSMALL = case_when(
    PROVPLATS_ANALYSMALL == 'Utlängan' ~ 'Utlängan (höst)',
    PROVPLATS_ANALYSMALL == 'Gotland SO' ~ 'Gotland So',
    PROVPLATS_ANALYSMALL == 'Västra Hanöbukten' ~ 'Hanöbukten',
    TRUE ~ PROVPLATS_ANALYSMALL
  ))

raw_data <- moc_join_SGU(biodata, analysdata) |>
  mutate(organ = case_when(
    ORGAN == 'MJUKKROPP' ~ 'Soft tissue',
    ORGAN == 'AGG' ~ 'Egg content',
    ORGAN == 'LEVER' ~ 'Liver',
    ORGAN == 'MUSKEL' ~ 'Muscle'
  )) |>
  drop_na(organ) |>
  mutate(unit = case_when(
    ENHET == 'ug.g-1.tv-1' ~ 'ug.g-1.dw-1',
    ENHET == 'ug.g-1.lv-1' ~ 'ug.g-1.lw-1',
    ENHET == 'pg.g-1.lv-1' ~ 'pg.g-1.lw-1',
    ENHET == 'ng.g-1.vv-1' ~ 'ng.g-1.ww-1',
    ENHET == 'ng.g-1.tv-1' ~ 'ng.g-1.dw-1', 
    ENHET == 'ng.g-1.lv-1' ~ 'ng.g-1.lw-1',
    ENHET == 'Procent_av_vv' ~ '%' #'dry_weight_percentage'
  )) |>
  drop_na(unit) |>
  mutate(is_censored = case_when(
    MATVARDETAL > RAPPORTERINGSGRANS_LOQ ~ 'FALSE',
    MATVARDETAL > DETEKTIONSGRANS_LOD ~ 'FALSE',
    TRUE ~ 'TRUE'
  )) |>
  mutate(specimen_ID = PROV_KOD_ORIGINAL, year= as.integer(str_sub(PROVTAG_DAT,1,4)), station_SGU= PROVPLATS_ANALYSMALL,
         date = PROVTAG_DAT, species = LATIN, 
         #d13C = D13CUCD, d15N = D15NUCD, C_dw_percentage = CUCDTPRC, N_dw_percentage = NUCDTPRC, ## NB ISOTOPES ADD IN
         value = abs(MATVARDETAL),  sample_ID = paste(PROV_KOD_ORIGINAL,"/",organ,sep=""), number_individuals = ANTAL, 
         age = ALDR, weight = TOTV, total_length=TOTL, sex = KON,
         season = ifelse((as.POSIXct(PROVTAG_DAT) |> format("%m")) < "07", "Spring", "Autumn")) |>
  left_join(station_table, by = 'station_SGU') |>
  left_join(cont, by = 'NRM_PARAMETERKOD') |>
  filter(NRM_PARAMETERKOD != 'BITSI')|> #filter(NRM_PARAMETERKOD != 'LPFHXS') |> filter(NRM_PARAMETERKOD != 'BPFHXS') |>
  select(specimen_ID, sample_ID, year, date, station_MCoM, species, number_individuals, organ, sex, substance_group, 
         contaminant, NRM_PARAMETERKOD, value, 
         unit, is_censored,age, weight, total_length,  season) |>
         #unit, is_censored,age, weight, total_length, d13C, d15N, C_dw_percentage, N_dw_percentage, season) |> ## NB ISOTOPES ADD IN
  # spelling mistakes in raw data metal files 2023
  mutate(
    species_EN = case_when(
    species == 'Perca fluviatilis' ~ 'European perch',
    species == 'Clupea harengus' ~ 'Atlantic herring',  
    species == 'Mytilus edulis' ~ 'Blue mussel',
    species == 'Gadus morhua' ~ 'Atlantic cod', 
    species == 'Zoarces viviparus' ~ 'Viviparous eelpout',
    species == 'Uria aalge' ~ 'Common guillemot', 
    species == 'Sterna hirundo' ~ 'Common Tern',
    species == 'Haematopus ostralegus' ~ 'Eurasian oystercatcher'
  ))


fp <- raw_data |>
  filter(NRM_PARAMETERKOD == 'FPRCU' | NRM_PARAMETERKOD == 'FPRC') |>rename(fat_percentage = 'value') |>
  select(c(sample_ID,species,organ,fat_percentage))

ltp <- raw_data |>
  filter(NRM_PARAMETERKOD == 'LTPRCI'|NRM_PARAMETERKOD == 'MTPRCI'|NRM_PARAMETERKOD=='TPRCIVL') |>
  rename(dry_weight_percentage = 'value') |>
  select(c(sample_ID,species,organ,dry_weight_percentage))
  

raw_data_MCoM <- raw_data |>
  filter(!NRM_PARAMETERKOD %in% c('FPRCU', 'MTPRCI', 'LTPRCI', 'TPRCIVL')) |>
  left_join(fp, by=c('sample_ID','species','organ')) |>
  left_join(ltp, by=c('sample_ID','species','organ')) |> #drop_na(contaminant)
  select(-c('NRM_PARAMETERKOD')) |>
  rename(station_name = 'station_MCoM') |>
  mutate(date = as.character(date), is_censored = as.logical(is_censored))

write_csv(raw_data_MCoM,paste("raw_data_MCoM_2025_v4.csv"))

#MCoM_raw <- mcomDb::MCoM |>
#  bind_rows(raw_data_MCoM)

#test <- raw_data_MCoM |> filter(organ == 'Liver'| organ=='Muscle') |> filter(is.na(date)) |> select(specimen_ID,year:species) |> distinct()

#test2 <- raw_data_MCoM |> filter(organ == 'Liver'| organ=='Muscle') |> filter(is.na(station_name)) |> select(specimen_ID,year:species) |> distinct()
