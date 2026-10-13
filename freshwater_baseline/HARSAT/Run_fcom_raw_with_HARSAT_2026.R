######################################v
# STEP 2: Run HARSAT ##########################
######################################v

rm(list = objects())

## Load HARSAT develop version ----
devtools::load_all()

##Download HARSAT from Github
library(devtools)
devtools::install_github("osparcomm/HARSAT@develop")
library(harsat)

## Read nrm functions ----
#source("../HARSAT_NRM/functions/HARSAT_nrm_functions.R")
source("functions/HARSAT_nrm_functions.R")
  
path <- ('<path-removed>/FCOM/FCOM26/fcom26_HARSAT/')

###################################################-
## Read data ----

biota_data_NRM <- read_data(   #method = 'name default, matches based on station name
  compartment = "biota", 
  purpose = 'custom', 
  #contaminants = "NRM_metals_2026_SF.csv",        # 
  contaminants = "NRM_PCB_PCDDF_2026_SF.csv",     # 
  #contaminants = "NRM_BFR_2026_SF.csv",           # all converged
  #contaminants = "NRM_pfas_2026.csv",          # all converged
  ## mcom only
  #contaminants = "NRM_PAH_2025_no_date.csv",   # 
  ## phased out
  #contaminants = "NRM_pes_sol_2026_SF.csv",       # all converged
  ######-
  ## seperate, now merged
  #contaminants = "NRM_PCB_2026_SF.csv",          
  ##contaminants = "NRM_PCDDF_2026.csv",   
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

#### conv for BFR ----

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
# STVI AL Esox lucius LI - not converged

biota_assessment_NRM <- update_assessment(
  biota_assessment_NRM, 
  subset=series=='ABIS PB Salvelinus alpinus LI',
  fixed_bound=10)

biota_assessment_NRM <- update_assessment(
  biota_assessment_NRM, 
  subset=series=='ALGS PB Perca fluviatilis LI',
  fixed_bound=20,
  hess.d=0.0001,
  hess.r=8)

biota_assessment_NRM <- update_assessment(
  biota_assessment_NRM, 
  subset=series=='ALLG AS Perca fluviatilis LI',
  fixed_bound=20,
  hess.d=0.0001,
  hess.r=8)

biota_assessment_NRM <- update_assessment(
  biota_assessment_NRM, 
  subset=series=='BOLM PB Esox lucius LI',
  fixed_bound=10)

biota_assessment_NRM <- update_assessment(
  biota_assessment_NRM, 
  subset=series=='BYSJ NI Perca fluviatilis LI',
  fixed_bound=20,
  hess.d=0.0001,
  hess.r=8)

biota_assessment_NRM <- update_assessment(
  biota_assessment_NRM, 
  subset=series=='FIOL CR Perca fluviatilis LI',
  fixed_bound=20,
  hess.d=0.0001,
  hess.r=8)

biota_assessment_NRM <- update_assessment(
  biota_assessment_NRM, 
  subset=series=='FIOL NI Perca fluviatilis LI',
  fixed_bound=20,
  hess.d=0.0001,
  hess.r=8)

biota_assessment_NRM <- update_assessment(
  biota_assessment_NRM, 
  subset=series=='FRAC AG Perca fluviatilis LI',
  fixed_bound=20,
  hess.d=0.0001,
  hess.r=8)

biota_assessment_NRM <- update_assessment(
  biota_assessment_NRM, 
  subset=series=='HJAR CR Perca fluviatilis LI',
  fixed_bound=10)

biota_assessment_NRM <- update_assessment(
  biota_assessment_NRM, 
  subset=series=='LIMM AS Perca fluviatilis LI',
  fixed_bound=20,
  hess.d=0.0001,
  hess.r=8)

biota_assessment_NRM <- update_assessment(
  biota_assessment_NRM, 
  subset=series=='LIMM PB Perca fluviatilis LI',
  fixed_bound=20,
  hess.d=0.0001,
  hess.r=8)

biota_assessment_NRM <- update_assessment(
  biota_assessment_NRM, 
  subset=series=='REMM PB Perca fluviatilis LI',
  fixed_bound=20,
  hess.d=0.0001,
  hess.r=8)

biota_assessment_NRM <- update_assessment(
  biota_assessment_NRM, 
  subset=series=='SKAR AS Perca fluviatilis LI',
  fixed_bound=20,
  hess.d=0.0001,
  hess.r=8)

biota_assessment_NRM <- update_assessment(
  biota_assessment_NRM, 
  subset=series=='SKAR CR Perca fluviatilis LI',
  fixed_bound=10)

biota_assessment_NRM <- update_assessment(
  biota_assessment_NRM, 
  subset=series=='STBA AS Perca fluviatilis LI',
  fixed_bound=20,
  hess.d=0.0001,
  hess.r=8)

biota_assessment_NRM <- update_assessment(
  biota_assessment_NRM, 
  subset=series=='STBJ NI Salvelinus alpinus LI',
  fixed_bound=10)

biota_assessment_NRM <- update_assessment(
  biota_assessment_NRM, 
  subset=series=='TJUL NI Salvelinus alpinus LI',
  fixed_bound=10)

biota_assessment_NRM <- update_assessment(
  biota_assessment_NRM, 
  subset=series=='TJUL PB Salvelinus alpinus LI',
  fixed_bound=10)

biota_assessment_NRM <- update_assessment(
  biota_assessment_NRM, 
  subset=series=='TJUL AS Salvelinus alpinus LI',
  fixed_bound=10)

biota_assessment_NRM <- update_assessment(
  biota_assessment_NRM, 
  subset=series=='STEN NI Perca fluviatilis LI',
  fixed_bound=10)

biota_assessment_NRM <- update_assessment(
  biota_assessment_NRM, 
  subset=series=='STEN AS Perca fluviatilis LI',
  fixed_bound=20,
  hess.d=0.0001,
  hess.r=8)

biota_assessment_NRM <- update_assessment(
  biota_assessment_NRM, 
  subset=series=='BAST AL Perca fluviatilis LI',
  fixed_bound=20,
  hess.d=0.0001,
  hess.r=8)

biota_assessment_NRM <- update_assessment(
  biota_assessment_NRM, 
  subset=series=='BRAN NI Perca fluviatilis LI',
  fixed_bound=20,
  hess.d=0.0001,
  hess.r=8)

biota_assessment_NRM <- update_assessment(
  biota_assessment_NRM, 
  subset=series=='GIPS AG Perca fluviatilis LI',
  fixed_bound=20,
  hess.d=0.0001,
  hess.r=8)

biota_assessment_NRM <- update_assessment(
  biota_assessment_NRM, 
  subset=series=='HORS PB Perca fluviatilis LI',
  fixed_bound=20,
  hess.d=0.0001,
  hess.r=8)

biota_assessment_NRM <- update_assessment(
  biota_assessment_NRM, 
  subset=series=='KRAG PB Perca fluviatilis LI',
  fixed_bound=20,
  hess.d=0.0001,
  hess.r=8)

biota_assessment_NRM <- update_assessment(
  biota_assessment_NRM, 
  subset=series=='KRAN NI Perca fluviatilis LI',
  fixed_bound=20,
  hess.d=0.0001,
  hess.r=8)

biota_assessment_NRM <- update_assessment(
  biota_assessment_NRM, 
  subset=series=='OVSK AS Perca fluviatilis LI',
  fixed_bound=20,
  hess.d=0.0001,
  hess.r=8)

biota_assessment_NRM <- update_assessment(
  biota_assessment_NRM, 
  subset=series=='SANN CR Perca fluviatilis LI',
  fixed_bound=20,
  hess.d=0.0001,
  hess.r=8)

biota_assessment_NRM <- update_assessment(
  biota_assessment_NRM, 
  subset=series=='SENV CR Perca fluviatilis LI',
  fixed_bound=20,
  hess.d=0.0001,
  hess.r=8)

biota_assessment_NRM <- update_assessment(
  biota_assessment_NRM, 
  subset=series=='STVI PB Esox lucius LI',
  fixed_bound=20,
  hess.d=0.0001,
  hess.r=8)

#biota_assessment_NRM <- update_assessment(
#  biota_assessment_NRM, 
#  subset=series=='STVI AL Esox lucius LI',
#  fixed_bound=20,
#  hess.d=0.0001,
#  hess.r=8)

biota_assessment_NRM <- update_assessment(
  biota_assessment_NRM, 
  subset=series=='TJUL PB Salvelinus alpinus LI',
  fixed_bound=10)

biota_assessment_NRM <- update_assessment(
  biota_assessment_NRM, 
  subset=series=='TJUL CR Salvelinus alpinus LI',
  fixed_bound=20,
  hess.d=0.0001,
  hess.r=8)


#### conv for PCDDF ----
biota_assessment_NRM <- update_assessment(
  biota_assessment_NRM, 
  subset=series=='BOLM HPCDF1 Esox lucius MU',
  fixed_bound=10)

biota_assessment_NRM <- update_assessment(
  biota_assessment_NRM, 
  subset=series=='BOLM HXCDD2 Esox lucius MU',
  fixed_bound=10)

biota_assessment_NRM <- update_assessment(
  biota_assessment_NRM, 
  subset=series=='DEGE CB180 Perca fluviatilis MU',
  fixed_bound=10)

biota_assessment_NRM <- update_assessment(
  biota_assessment_NRM, 
  subset=series=='REMM CB180 Perca fluviatilis MU',
  fixed_bound=10)

biota_assessment_NRM <- update_assessment(
  biota_assessment_NRM, 
  subset=series=='BOLM OCDF Esox lucius MU',
  fixed_bound=20,
  hess.d=0.0001,
  hess.r=8)

### check convergence again ----
check_assessment(biota_assessment_NRM)


## Save assessment object

#save(biota_assessment_NRM, file = paste0(path,"saved_objects/harsat_nrm_metals_2026_10L_SF.Rdata")) #OBS alla har inte converge
save(biota_assessment_NRM, file = paste0(path,"saved_objects/harsat_nrm_PCB_PCDDF_2026_10L_SF.Rdata"))
#save(biota_assessment_NRM, file = paste0(path,"saved_objects/harsat_nrm_BFR_2026_10L_SF.Rdata"))
#save(biota_assessment_NRM, file = paste0(path,"saved_objects/harsat_nrm_PFAS_2026_10L_SF.Rdata"))
#save(biota_assessment_NRM, file = paste0(path,"saved_objects/harsat_nrm_pes_sol_2026_10L_SF.Rdata"))
## just MCoM 
#save(biota_assessment_NRM, file = paste0(path,"saved_objects/harsat_nrm_PAH_2026_10L.Rdata"))
##-
##save(biota_assessment_NRM, file = paste0(path,"saved_objects/harsat_nrm_PCDDF_2026_10L.Rdata"))
#save(biota_assessment_NRM, file = paste0(path,"saved_objects/harsat_nrm_PCB_2026_10L.Rdata"))
