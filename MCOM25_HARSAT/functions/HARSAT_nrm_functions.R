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
# Function to rename figures ----
####################################################-

fix_name <- function(name){
  station <- str_extract(name, "^[A-Z0-9]+")
  contaminant <- str_extract(str_remove(name, station),"[A-Z0-9]+")
  species <- str_sub(str_remove(name, paste(station, contaminant)), 2, 5) |> toupper()
  # Change species to "SIGR" only if it is "URIA" - for MoCiS markdown script
  if (species == "URIA") {
    species <- "SIGR"
  }
  paste(station, species, contaminant, sep = "_")
}


####################################################-
# Function to plot figures ----
####################################################-

ts_plot <- function(assessment, obs){
  
  obs_ind <- assessment$data # OBS
  obs_ind <- obs_ind |>
    mutate(LOQ = NA,
      LOQ = ifelse(censoring == "<", concentration, NA),
      LOQ = as.numeric(LOQ))# Column for values where condition is '<'
  
    
  obs_avg<-assessment$annualIndex |>
    mutate(obs_avg = exp(index)) |>
    mutate(LOQ = NA,
           LOQ = ifelse(censoring == "<", obs_avg, NA),
           LOQ = as.numeric(LOQ))# Column for values where condition is '<'
  
  if ("pred" %in% names(assessment)){
  pred <- assessment$pred |>
    mutate(pred_conc = exp(fit), upper = exp(ci.upper), lower = exp(ci.lower))
  } else {
    NULL
  }
  
  if ('reference.values' %in% names(assessment)){
  EQS<-assessment$reference.value |>
    mutate(threshold = exp(refvalue))
  EQS_e <- EQS[1,7]
  } else {
    NULL
  }
  
  # y-axis text
  determinand <- obs$determinand
  determinand <- ifelse(determinand == 'AG','Ag', ifelse(determinand == 'AL','Al', ifelse(determinand == 'AS','As',
                 ifelse(determinand == 'CD','Cd', ifelse(determinand == 'CR','Cr', ifelse(determinand == 'CU','Cu',
                 ifelse(determinand == 'HG','Hg', ifelse(determinand == 'NI','Ni', ifelse(determinand == 'PB','Pb',
                 ifelse(determinand == 'SE','Se', ifelse(determinand == 'ZN','Zn',
                 ifelse(determinand == 'TEQDF','TCDD-equivalents', ifelse(determinand == 'TEQ','TCDD-equivalents',
                 ifelse(determinand == 'PFHXA','PFHxA', ifelse(determinand == 'PFHPA','PFHpA',ifelse(determinand == 'PFUNDA','PFUnDA',
                 ifelse(determinand == 'PFDODA','PFDoDA', ifelse(determinand == 'PFTRDA','PFTrDA', ifelse(determinand == 'PFTEDA','PFTeDA',
                 ifelse(determinand == 'PFPEDA','PFPeDA', ifelse(determinand == 'LPFBS','l-PFBS', ifelse(determinand == 'PFHXS','PFHxS',   
                 ifelse(determinand == 'LPFOS','l-PFOS', ifelse(determinand == 'BPFOS','b-PFOS', ifelse(determinand == 'LPFDS','l-PFDS', 
                 ifelse(determinand == 'LFOSA','l-FOSA', ifelse(determinand == 'BFOSA','b-FOSA', 
                 ifelse(determinand == 'SUMPAH','Sum PAHs', ifelse(determinand == 'NAP','Naphtalene', ifelse(determinand == 'ACNE','Acenapthene',
                 ifelse(determinand == 'FLE','Flourene', ifelse(determinand == 'PA','Phenantrene', ifelse(determinand == 'ANT','Anthracene',
                 ifelse(determinand == 'FLU','Flouranthene', ifelse(determinand == 'PYR','Pyrene', ifelse(determinand == 'BAA','Benso(a)anthracene',
                 ifelse(determinand == 'CHR','Chrysene', ifelse(determinand == 'BBF','Benso(b)fluoranthene', ifelse(determinand == 'BKF','Benso(k)fluoranthene',
                 ifelse(determinand == 'BAP','Benso(a)pyrene', ifelse(determinand == 'BGHIP','Benso(g,h,i)perylene', 
                 ifelse(determinand == 'DBAHA','Dibenso(a,h)anthracene', ifelse(determinand == 'ICDP','Indeno(1,2,3)pyrene',
                 ifelse(determinand == 'PFAS24','PFOA-equivalents',
                 determinand ))))))))))))))))))))))))))))))))))))))))))))
  unit <- obs$unit
  basis <- obs$basis
  basis <- ifelse(basis == "W", "ww", ifelse(basis == "D", "dw", ifelse(basis == "L", "lw", basis)))
  matrix <- obs$matrix
  matrix <- ifelse(matrix == "MU","muscle", ifelse(matrix == "LI", "liver", 
            ifelse(matrix == "SB", "soft body", ifelse(matrix == "EH", "egg content", matrix))))
  y_axis <- paste(determinand,unit,basis,matrix)
  #y_axis <- paste(determinand,unit,basis,matrix, sep = ' ')
  
  # figure title
  station <- obs$station_code
  station <- ifelse(station == 'ABBE','Abbekås', ifelse(station == 'ANGK','Ängskärsklubb',
             ifelse(station == 'ANGV','Ängskärsklubb spring', ifelse(station == 'BYXE','Byxelkrok',
             ifelse(station == 'FJBA','Fjällbacka', ifelse(station == 'FLAD','Fladen',
             ifelse(station == 'GAFJ','Gaviksfjärden', ifelse(station == 'HABU','Hanöbukten',
             ifelse(station == 'HAFJ','Harufjärden', ifelse(station == 'HOLM','Holmöarna',
             ifelse(station == 'KIFJ','Kinnbäcksfjärden', ifelse(station == 'KULL','Kullen',
             ifelse(station == 'KVFJ','Kvädöfjärden', ifelse(station == 'LAFJ','Långvindsfjärden',
             ifelse(station == 'LAGN','Lagnö', ifelse(station == 'LAND','Landsort',
             ifelse(station == 'NIDI','Nidingen', ifelse(station == 'ORFJ','Örefjärden', 
             ifelse(station == 'RAFJ','Rånefjärden', ifelse(station == 'SEGO','SE Gotland',
             ifelse(station == 'STKA','Stora Karlsö', ifelse(station == 'TJRN','Tjärnö',
             ifelse(station == 'UTLA', 'Utlängan', ifelse(station == 'UTLV','Utlängan spring',
             ifelse(station == 'VADO','Väderöarna', ifelse(station == '40G7','E. Bornholm Basin offshore',
             ifelse(station == '46H0', 'N. Baltic Proper offshore', ifelse(station == '49G9','Åland Sea offshore',
             ifelse(station == '51G9','Bothnian Sea offshore', station)))))))))))))))))))))))))))))
             # lakes
  station <- ifelse(station == 'ABIS','Abiskojaure', ifelse(station == 'TJUL','Stor-Tjulträsket',
             ifelse(station == 'STVI','Storvindel', ifelse(station == 'BRAN','Brännträsket',
             ifelse(station == 'DEGE','Degervattnet', ifelse(station == 'REMM','Remmarsjön',
             ifelse(station == 'STBJ','Stor-Björsjön', ifelse(station == 'STBA','Stor-Backsjön',
             ifelse(station == 'STEN','Stensjön', ifelse(station == 'GIPS','Gipsjön',
             ifelse(station == 'SPJU','Spjutsjön', ifelse(station == 'OVSK','Övre Skärsjön',
             ifelse(station == 'LIMM','Limmingsjön', ifelse(station == 'FYSI','Fysingen',
             ifelse(station == 'TARN','Tärnan', ifelse(station == 'BYSJ','Bysjön',
             ifelse(station == 'SENV','Stora Envättern', ifelse(station == 'ALGS','Älgsjön', 
             ifelse(station == 'SVAR','Svartsjön', ifelse(station == 'FRAC','Fräcksjön',
             ifelse(station == 'ALLG','Allgjuttern', ifelse(station == 'BAST','Bästeträsk',
             ifelse(station == 'HORS','Horsan', ifelse(station == 'SKAR','Skärgölen',
             ifelse(station == 'LORE','Lilla Öresjön', ifelse(station == 'FIOL','Fiolen',
             ifelse(station == 'HJAR','Hjärtsjön', ifelse(station == 'BOLM','Bolmen',
             ifelse(station == 'STSK','Stora Skärsjön', ifelse(station == 'SANN','Sännen',
             ifelse(station == 'KRAN','Krankesjön', ifelse(station == 'KRAG','Krageholmssjön',
             station))))))))))))))))))))))))))))))))
  
  species <- obs$species
  species <- ifelse(species == 'Clupea harengus','herring', ifelse(species == 'Zoarces viviparus','eelpout',
             ifelse(species == 'Mytilus edulis','blue mussel', ifelse(species == 'Gadus morhua', 'cod',
             ifelse(species == 'Perca fluviatilis','perch', ifelse(species == 'Uria aalge','guillemot',
             ifelse(species == 'Haematopus ostralegus','Eurasian oystercatcher', ifelse(species == 'Sterna hirundo','tern',
             ifelse(species == 'Salvelinus alpinus','Arctic char', ifelse(species == 'Esox lucius','pike',
             species))))))))))
  title <- paste(station,species, sep = ' - ')
  
  ggplot() +
    {
      if ('reference.values' %in% names(assessment)){
        hline_layer <- geom_hline(yintercept = EQS_e, linetype = 'dashed')  # Add colored area below the horizontal line
        #ribbon_layer <- geom_ribbon(data = pred, aes(x = year, ymin = 0, ymax = EQS_e), fill = "lightgreen", alpha = 0.3)
        ribbon_layer <- geom_ribbon(data = obs_avg, aes(x = year, ymin = 0, ymax = pmin(EQS_e, max(obs_avg*1.5, na.rm = TRUE))), fill = "lightgreen", alpha = 0.3)
        list(hline_layer, ribbon_layer)         # Combine the hline and ribbon layers
      } else {
        NULL
      }
    } +
    geom_point(data=obs_ind, aes(x = year, y = concentration), size = 0.75, color = 'black') + #OBS
    geom_point(data=obs_ind, aes(x = year, y = LOQ), size = 1, color = '#FF6600') +
    geom_point(data=obs_avg, aes(x = year, y = obs_avg), size=2, color ='black') +
    geom_point(data=obs_avg, aes(x = year, y = LOQ), size=2, color ='#FF6600') +
    # Add geom_line and geom_ribbon only if 'pred' exists and has data
    { 
      if (!is.null(assessment$pred)){
        list(
          geom_line(data = pred, aes(x = year, y = pred_conc), alpha = .1, linetype = 'solid', color = 'black'),
          geom_ribbon(data = pred, aes(x = year, ymax = `upper`, ymin = `lower`), fill = "black", alpha = 0.25)
        )
      } else {
        NULL  
      }
    } + 
    ylab(y_axis) +
    ggtitle(title) +
    theme_classic() +
    theme(text=element_text(size=15),
          axis.text.x = element_text(color = "black"), 
          axis.text.y = element_text(color = "black"))+
    #scale_y_continuous(limits = c(0, NA))  # Ensure the y-axis starts from 0
    scale_y_continuous(limits = c(0, max(obs_avg$obs_avg*1.5, na.rm = TRUE)))  # Ensure the y-axis starts from 0
}

