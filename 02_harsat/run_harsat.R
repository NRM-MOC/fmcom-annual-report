######################################v
# Run HARSAT ##########################
######################################v

rm(list = objects())

## Load HARSAT develop version ----
devtools::load_all()

## Read nrm functions ----
source("../HARSAT_NRM/functions/HARSAT_nrm_functions.R")
  
path <- ('<path-removed>/MCOM2025/MCOM25_HARSAT/')

###################################################-
## Read data ----

biota_data_NRM <- read_data(   #method = 'name default, matches based on station name
  compartment = "biota", 
  purpose = 'custom', 
  #contaminants = "NRM_metals_2025.csv",        # 8 not converged, 2 unresolved with most common adjustments
  #contaminants = "NRM_PAH_2025_no_date.csv",   # all converged
  #contaminants = "NRM_PCB_PCDDF_2025.csv",     # 6 not converged, all resolved
  #contaminants = "NRM_BFR_2025.csv",           # 5 not converged, 1 unresolved
  #contaminants = "NRM_pes_sol_2025.csv",       # 10 not converged, 1 unresolved
  contaminants = "NRM_pfas_2025.csv",           # 2 not converged, 1 unresolved
  ######-
  ##contaminants = "NRM_PCB_2025.csv",           # 5 not converged, all resolved
  ##contaminants = "NRM_PCDDF_2025.csv",         # 1 not converged, all resolved - basis query problem
  stations = "stations.csv", 
  data_dir = file.path(paste(path,"data",sep='')),
  data_format = "external",
  info_dir = file.path(paste(path,"information",sep='')),
  control = list(region = list(id = "regionLevel2"))
) 


#wk<- read.csv(file.path("data", "NRM_test.csv"), na = "")
## Prepare/tidy data for next stage ----

# get correct variables and streamline the data files

biota_data_NRM <- tidy_data(biota_data_NRM)

## Subscribe weighted sums ----

### PCDDF and dl-PCBs ----
info_TEF_PCDDF <- c(  "TCDD" = 1, "PECDD" = 1, "HXCDD1" = 0.1, "HXCDD2" = 0.1, "HXCDD3" = 0.1, 
                      "HPCDD" = 0.01, "OCDD" = 0.0003, "TCDF" = 0.1, "PECDF1" = 0.03,
                      "PECDF2" = 0.3, "HXCDF1" = 0.1, "HXCDF2" = 0.1, "HXCDF3" = 0.1,
                      "HXCDF4" = 0.1, "HPCDF1" = 0.01, "HPCDF2" = 0.01, "OCDF" = 0.0003)
  
info_TEF_dlPCB <- c( "CB77" = 0.0001, "CB81" = 0.0003, "CB126" = 0.1, "CB169" = 0.03, 
                     "CB105" = 0.00003, "CB114" = 0.00003, "CB118" = 0.00003, "CB123" = 0.00003,
                     "CB156" = 0.00003, "CB157" = 0.00003, "CB167" = 0.00003, "CB189" = 0.00003)

info_TEF <- c(info_TEF_dlPCB,info_TEF_PCDDF)

### PFAS24 (only 6 most important -OSPAR- included) ----
info_RPF_PFAS <- c("PFOS" = 2, "PFOA" = 1, "PFNA" = 10, "PFDA" = 7, "PFUNDA" = 4, "PFDODA" = 3,"PFTRDA" = 1.35)

###################################################-
## Construct timeseries ----

# for each time series, use the basis which has been most reported in the data

biota_timeseries_NRM <- create_timeseries(
  biota_data_NRM,  
  #get_basis = get_basis_most_common, # this will use the most common basis given for the sub-group of contaminants, for example metals or PFAS
  #get_basis = get_basis_default,
  get_basis = get_basis_nrm,
  # add any corrections or summations, three choices: sum, bespoke, replace
  determinands.control = list(
    PFOS = list(det = c("LPFOS", "BPFOS"), action = "sum"),
    FOSA = list(det = c("LFOSA", "BFOSA"), action = "sum"),
    PFDS = list(det = c("LPFDS", "BPFDS"), action = "sum"),
    PFHXS = list(det = c("LPFHXS", "BPFHXS"), action = "sum"),
    #PFBS = list(det = c("LPFBS", "BPFBS"), action = "sum"),
    TEQDF = list(det = names(info_TEF_PCDDF), action = "sum",weights = info_TEF_PCDDF),
    TEQDLP = list(det = names(info_TEF_dlPCB), action = "sum",weights = info_TEF_dlPCB),
    TEQ = list(det = names(info_TEF), action = "sum",weights = info_TEF),
    PFAS24 = list(det = names(info_RPF_PFAS), action = "sum",weights = info_RPF_PFAS),
    SUMPBDE = list(det = c("BDE47","BDE99","BDE100","BDE153","BDE154"), action = 'sum'), #"BDE28",
    SUMPAH = list(det = c('NAP','ACNE','FLE','PA','ANT','FLU','PYR','BAA','CHR','BBF',
                          'BKF','BAP','BGHIP','DBAHA','ICDP'), action = 'sum')
  ), 
)


###################################################-
## Assessment ----

### Assessment run ----

biota_assessment_NRM <- run_assessment(
  biota_timeseries_NRM, 
  recent_trend = 10L,   # trend for the last 10 years as recent trend (default 20)
  AC = c("EQS","EAC"),  # more thresholds can be added
  parallel = TRUE
)


### Check convergence ----
check_assessment(biota_assessment_NRM)


### treatment of non-converged data ----
#### conv for solvents ----
biota_assessment_NRM <- update_assessment(
  biota_assessment_NRM, 
  subset=series=='ANGK AHCH Clupea harengus MU',
  fixed_bound=10)

biota_assessment_NRM <- update_assessment(
  biota_assessment_NRM, 
  subset=series=='ANGK LINDAN Clupea harengus MU',
  fixed_bound=10)

biota_assessment_NRM <- update_assessment(
  biota_assessment_NRM, 
  subset=series=='FJBA DDD Mytilus edulis SB',
  fixed_bound=10)

biota_assessment_NRM <- update_assessment(
  biota_assessment_NRM, 
  subset=series=='KVFJ AHCH Mytilus edulis SB',
  fixed_bound=20)

biota_assessment_NRM <- update_assessment(
  biota_assessment_NRM, 
  subset=series=='HAFJ AHCH Clupea harengus MU',
  fixed_bound=30)

biota_assessment_NRM <- update_assessment(
  biota_assessment_NRM, 
  subset=series=='HAFJ BHCH Clupea harengus MU',
  fixed_bound=30)

biota_assessment_NRM <- update_assessment(
  biota_assessment_NRM, 
  subset=series=='LAND DDT Clupea harengus MU',
  hess.d=0.0001,
  hess.r=8)

biota_assessment_NRM <- update_assessment(
  biota_assessment_NRM, 
  subset=series=='FJBA DDT Zoarces viviparus MU',
  hess.d=0.0001,
  hess.r=8)

biota_assessment_NRM <- update_assessment(
  biota_assessment_NRM, 
  subset=series=='ANGK DDT Clupea harengus MU',
  hess.d=0.0001,
  hess.r=8)


#### conv for BFR ----
biota_assessment_NRM <- update_assessment(
  biota_assessment_NRM, 
  subset=series=='46H0 BDE153 Clupea harengus MU',
  fixed_bound=10)

biota_assessment_NRM <- update_assessment(
  biota_assessment_NRM, 
  subset=series=='LAFJ BDE153 Clupea harengus MU',
  fixed_bound=10)

biota_assessment_NRM <- update_assessment(
  biota_assessment_NRM, 
  subset=series=='LAND BDE28 Clupea harengus MU',
  fixed_bound=10)

biota_assessment_NRM <- update_assessment(
  biota_assessment_NRM, 
  subset=series=='RAFJ BDE28 Clupea harengus MU',
  fixed_bound=10)

#### conv for PFAS ----
biota_assessment_NRM <- update_assessment(
  biota_assessment_NRM, 
  subset=series=='SEGO FOSA Gadus morhua LI',
  fixed_bound=10)

biota_assessment_NRM <- update_assessment(
  biota_assessment_NRM, 
  subset=series=='GAFJ PFHXS Clupea harengus LI',
  fixed_bound=10)

#### conv for PCBs ----
biota_assessment_NRM <- update_assessment(
  biota_assessment_NRM, 
  subset=series=='VADO CB28 Clupea harengus MU',
  fixed_bound=10)

biota_assessment_NRM <- update_assessment(
  biota_assessment_NRM, 
  subset=series=='FLAD CB28 Clupea harengus MU',
  fixed_bound=10,
  hess.d=0.0001,
  hess.r=8)

biota_assessment_NRM <- update_assessment(
  biota_assessment_NRM, 
  subset=series=='FJBA CB180 Mytilus edulis SB',
  fixed_bound=10)

biota_assessment_NRM <- update_assessment(
  biota_assessment_NRM, 
  subset=series=='STKA CB52 Uria aalge EH',
  fixed_bound=10,
  hess.d=0.0001,
  hess.r=8)

biota_assessment_NRM <- update_assessment(
  biota_assessment_NRM, 
  subset=series=='ANGK CB28 Clupea harengus MU',
  fixed_bound=10)

#### conv for metals ----
biota_assessment_NRM <- update_assessment(
  biota_assessment_NRM, 
  subset=series=='HAFJ CR Clupea harengus LI',
  fixed_bound=10)

biota_assessment_NRM <- update_assessment(
  biota_assessment_NRM, 
  subset=series=='ANGV CR Clupea harengus LI',
  fixed_bound=10)

biota_assessment_NRM <- update_assessment(
  biota_assessment_NRM, 
  subset=series=='HOLM PB Perca fluviatilis LI',
  fixed_bound=10)

biota_assessment_NRM <- update_assessment(
  biota_assessment_NRM, 
  subset=series=='SEGO CR Gadus morhua LI',
  fixed_bound=10)

biota_assessment_NRM <- update_assessment(
  biota_assessment_NRM, 
  subset=series=='UTLV CR Clupea harengus LI',
  fixed_bound=10)

biota_assessment_NRM <- update_assessment(
  biota_assessment_NRM, 
  subset=series=='FJBA CR Zoarces viviparus LI',
  fixed_bound=10)

#### conv for PCDDF ----
biota_assessment_NRM <- update_assessment(
  biota_assessment_NRM, 
  subset=series=='HAFJ HXCDF2 Clupea harengus MU',
  hess.d=0.0001,
  hess.r=8)


### check convergence again ----
check_assessment(biota_assessment_NRM)


## Save assessment object
#save(biota_assessment_NRM, file = paste0(path,"saved_objects/harsat_nrm_PAH_2025_10L.Rdata"))
#save(biota_assessment_NRM, file = paste0(path,"saved_objects/harsat_nrm_metals_2025_10L.Rdata"))
#save(biota_assessment_NRM, file = paste0(path,"saved_objects/harsat_nrm_PCB_PCDDF_2025_10L.Rdata"))
#save(biota_assessment_NRM, file = paste0(path,"saved_objects/harsat_nrm_BFR_2025_10L.Rdata"))
save(biota_assessment_NRM, file = paste0(path,"saved_objects/harsat_nrm_PFAS_2025_10L_v1_0_6_test.Rdata"))
#save(biota_assessment_NRM, file = paste0(path,"saved_objects/harsat_nrm_pes_sol_2025_10L.Rdata"))
##save(biota_assessment_NRM, file = paste0(path,"saved_objects/harsat_nrm_pcddf_2025_10L.Rdata"))
##save(biota_assessment_NRM, file = paste0(path,"saved_objects/harsat_nrm_PCB_2025_10L.Rdata"))