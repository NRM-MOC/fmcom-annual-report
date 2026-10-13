# Report_MCOM_results ----
#
# Be in HARAST directory when running script

rm(list = objects())

## Load HARSAT develop version ----
devtools::load_all()

## Libraries ----
library(tidyverse)
library(readxl)
library(knitr)
library(scales)
library(rnaturalearth)
library(rnaturalearthdata)
library(sf)
library(cowplot)
library(ggspatial)

## Initiate ----

### Name folder ----
folder <- ('MCoM_2025_10L')
path <- ('<path-removed>/MCOM2025/MCOM25_HARSAT/')

## Read nrm functions ----
source(paste (path,"functions/HARSAT_nrm_functions.R",sep=''))

### Create folder ----
summary.dir <- file.path(paste(path,"output/", folder,sep=''))

if (!dir.exists(summary.dir)) {
  dir.create(summary.dir, recursive = TRUE)
}

summary.dir <- file.path(paste(path,"output/", folder,"/figs",sep=''))

if (!dir.exists(summary.dir)) {
  dir.create(summary.dir, recursive = TRUE)
}

summary.dir <- file.path(paste(path,"output/", folder,"/tables",sep=''))

if (!dir.exists(summary.dir)) {
  dir.create(summary.dir, recursive = TRUE)
}

### Set contamiant groups ----
#cont_short <- c('metals','PFAS','pes_sol','PCDDF','PAH','BFR','PCB')
#cont_long <- c("Metals", "Organofluorines", "Chlorinated pesticides","Dioxins", "PAH_parent", "Organobromines", "Chlorobiphenyls")

cont_short <- c('metals','PFAS','pes_sol','PCB_PCDDF','PAH','BFR')
cont_long <- list("Metals", "Organofluorines", "Chlorinated pesticides",c("Chlorobiphenyls","Dioxins"), "PAH_parent", "Organobromines")

m <- length(cont_short)

### Set figure dimensions (e.g., 10x10 inches at 300 dpi) ----
width_in_inches <- 6   # adjust width in inches
height_in_inches <- 6  # adjust height in inches
dpi_value <- 300        # adjust dpi for desired resolution


##################################################-
## Print table and figures ----
##################################################-

for (j in 1:m) {
  object <- c(paste(path,"saved_objects/harsat_nrm_",cont_short[j],"_2025_10L.Rdata",sep=''))
  
  load(object)
  
  # ### Print large table ----
  # write_summary_table(
  #   biota_assessment_NRM,
  #   determinandGroups = list(
  #     levels = cont_long[[j]], 
  #     labels = cont_long[[j]]),
  #     #levels = cont_long[j], 
  #     #labels = cont_long[j]),
  #   extra_output = "power",                                    
  #   #collapse_AC = list(EAC = "EQS"),
  #   output_dir = file.path(path,"output", folder),
  #   append = TRUE
  #   # export = FALSE  # FALSE means the summary table will be returned as an R object
  # )

  results <- biota_assessment_NRM
  
  n <- length(results$assessment)
  
  ## Print ggplot figures for markdown----
  # for (i in 1:n) {
  #   file_name <- paste0(path,"output/",folder,"/figs/", 
  #                       fix_name(names(results$assessment)[i]), ".pdf")
  #   ggsave(ts_plot(results$assessment[[i]], results$timeSeries[i, ]), 
  #          file = file_name, 
  #          width = width_in_inches, 
  #          height = height_in_inches, 
  #          dpi = dpi_value)
  # }
  
  for (i in 1:n) {
   file_name <- paste0(path,"output/",folder,"/figs/", 
                       fix_name(names(results$assessment)[i]), ".png")
   ggsave(ts_plot(results$assessment[[i]], results$timeSeries[i, ]),
          file = file_name,
          width = width_in_inches,
          height = height_in_inches,
          dpi = dpi_value)
  }
}

##################################################-
## Print tables for markdown ----
##################################################-

#tables <- read.csv(paste("../HARSAT_NRM/output/",folder,"/biota_summary.csv", sep=''), header=FALSE)
tables <- read.csv(paste(path,"output/",folder,"/biota_summary.csv", sep='')) 

#colnames(tables) <- c("series", "region", "C1","station_code","Station",'C2','Latitude','Longitude','C3','C4','Cont_short',
#                      'Contaminant','Species','matrix','basis','unit','sex','C5','C6','shape','C7','n year all','n year fit',
#                      'n_year_positive','first_year_all','first_year_fit','last_year',
#                      'p nonlinear','p linear','p change','p linear trend','linear trend','p recent trend', # what is p
#                      'recent trend','detectable trend',
#                      'power dt obs','power dt seq','power dt ten','power ny seq','power pv obs','power pw seq','power pw ten',
#                      'mean last year','climit last year','threshold','EQS diff','EQS achieved','below')#,
#                      #'EAC','EAC_diff'#,'EAC achieved','EAC below')

#t1 <- tables |> ## merge first and last year
#  mutate(years = paste(first_year_all,last_year,sep="-")) |>
#mutate(`p linear trend` = round(`p linear trend`,3),
#       `p nonlinear` = round(`p nonlinear`,3),`p linear` = round(`p linear`,3),
#       `p change` = round(`p change`,3),`p recent trend` = round(`p recent trend`,3),
#       `mean last year` = round(`mean last year`,4),`climit last year` = round(`climit last year`,4),
#       `threshold` = round(`threshold`,3)) |>
#  select('Cont_short','Station','Species','Latitude','Longitude',
#         'n year all','n year fit','years','p nonlinear','p linear','p change',
#         'linear trend','p linear trend','detectable trend',
#         #'power dt obs','power dt ten',
#         'recent trend','p recent trend','mean last year','climit last year','threshold') |>
#  mutate(Station = case_when(
#    Station == 'Angskarsklubb_S' ~ 'Ängskärsklubb spring',
#    Station == 'Utlangan_S' ~ 'Utlängan spring',
#    Station == 'Eastern Bornholm Basin, offshore' ~ 'E Bornholm offshore',
#    Station == 'Northern Baltic Proper, offshore'~ 'N Baltic Proper offshore',
#    Station == 'Bothnian Sea, offshore' ~ 'Bothnian Sea offshore',
#    Station == 'Aland Sea, offshore' ~ 'Åland Sea offshore',
#    TRUE ~ Station
#  ))
  

t1 <- tables |> ## merge first and last year
  select(series:EQS_value) |>
  mutate(years = paste(first_year_all,last_year,sep="-")) |>
  mutate(`p_linear_trend` = round(`p_linear_trend`,3),
         `p_nonlinear_trend` = round(`p_nonlinear_trend`,3),`p_overall_trend` = round(`p_overall_trend`,3),
         `p_overall_change` = round(`p_overall_change`,3),`p_recent_change` = round(`p_recent_change`,3),
         `mean_last_year` = round(`mean_last_year`,4),`climit_last_year` = round(`climit_last_year`,4),
         `EQS_value` = round(`EQS_value`,3)) |>
  select('determinand','station_name','species','station_latitude','station_longitude',
         'n_year_all','n_year_fit','years','p_nonlinear_trend','p_linear_trend','p_overall_trend',
         'overall_change','p_overall_change','detectable_trend',
         #'power dt obs','power dt ten',
         'recent_change','p_recent_change','mean_last_year','climit_last_year','EQS_value') |>
  rename(Station = 'station_name',Latitude ='station_latitude',Longitude ='station_longitude',
         Species = 'species',Cont_short ='determinand', threshold = 'EQS_value',
         "n year all" = "n_year_all", "n year fit" = "n_year_fit", "p nonlinear trend" = "p_nonlinear_trend",
         "p linear trend"= "p_linear_trend","p overall trend" = "p_overall_trend",
         "overall change" = "overall_change", "p overall change" = "p_overall_change",
         "detectable trend" = "detectable_trend", "recent change" = "recent_change",
         "p recent change"="p_recent_change","mean last year" = "mean_last_year",
         "climit last year" = "climit_last_year")|>
  mutate(Station = case_when(
    Station == 'Angskarsklubb_S' ~ 'Ängskärsklubb spring',
    Station == 'Utlangan_S' ~ 'Utlängan spring',
    Station == 'Eastern Bornholm Basin, offshore' ~ 'E Bornholm offshore',
    Station == 'Northern Baltic Proper, offshore'~ 'N Baltic Proper offshore',
    Station == 'Bothnian Sea, offshore' ~ 'Bothnian Sea offshore',
    Station == 'Aland Sea, offshore' ~ 'Åland Sea offshore',
    TRUE ~ Station
  ))

t2 <- t1 |>
  mutate(Station = fct_reorder(Station, -(-1)^(Longitude > 13.6)*Latitude)) |>
  arrange(desc(Station)) |>
  select(-c(Latitude,Longitude))

herring_data <-  t2 |> 
        filter(Species == "Clupea harengus")
      fish_data <- t2 |> 
        filter(Species %in% c("Perca fluviatilis", "Gadus morhua", "Zoarces viviparus"))
      mussel_data <- t2 |> 
        filter(Species == "Mytilus edulis")
      egg_data <- t2 |> 
        filter(Species %in% c("Uria aalge", "Sterna hirundo", "Haematopus ostralegus"))
      
grouped_herring <- split(herring_data, herring_data$Cont_short)
      for (group in names(grouped_herring)) {
        subset_herring <- grouped_herring[[group]] |>
          select(-c(Cont_short))
      
        write.csv(subset_herring, paste0(path,"/output/",folder,"/tables/",group,"_herring_table.csv",sep=''), row.names=FALSE)
      }
      
      #if (nrow(herring_data) > 0){
      #  mocis_table(herring_data) %>%
      #    select(-var, -gen, -loc) %>% 
      #    write_csv(path = paste0("tables/", all_vars$var[row], "_herring_table.csv"))
      #}

grouped_fish <- split(fish_data, fish_data$Cont_short)
for (group in names(grouped_fish)) {
  subset_fish <- grouped_fish[[group]] |>
    select(-c(Cont_short))
  
  write.csv(subset_fish, paste0(path,"output/",folder,"/tables/",group,"_fish_table.csv",sep=''), row.names=FALSE)
}
grouped_mussel <- split(mussel_data, mussel_data$Cont_short)
for (group in names(grouped_mussel)) {
  subset_mussel <- grouped_mussel[[group]] |>
    select(-c(Cont_short))
  
  write.csv(subset_mussel, paste0(path,"output/",folder,"/tables/",group,"_mussel_table.csv",sep=''), row.names=FALSE)
}
grouped_egg <- split(egg_data, egg_data$Cont_short)
for (group in names(grouped_egg)) {
  subset_egg <- grouped_egg[[group]] |>
    select(-c(Cont_short))
  
  write.csv(subset_egg, paste0(path,"output/",folder,"/tables/",group,"_egg_table.csv",sep=''), row.names=FALSE)
}


## Mean figs ----
world_map <- ne_countries(scale = "medium", returnclass = "sf") |> 
  st_crop(c(xmin=8, xmax=25, ymin=54, ymax=70))

mf <- t1 |>
  mutate(Station = fct_reorder(Station, -(-1)^(Longitude > 13.6)*Latitude)) |>
  arrange(desc(Station)) |> 
  filter(Species == "Clupea harengus") |> 
  rename(recent_change = 'recent change', mean_last_year = 'mean last year') |>
  select(Cont_short, Station, Species, Longitude, Latitude, threshold, recent_change, mean_last_year)

cont <- mf |> distinct(Cont_short, threshold)


q <- nrow(cont)

for (idx in (1:q)){
  sub_data <- mf |> filter(Cont_short==cont[idx,1])
  p <- plot_grid(ggplot(world_map) + 
                   geom_sf(color = "white", fill = "grey") + 
                   annotation_north_arrow(location = "tl", height = unit(0.7, "cm"), width = unit(0.7, "cm")) +
                   annotation_scale() +
                   coord_sf(xlim = c(8, 25), ylim = c(54, 70), expand = FALSE) +
                   geom_point(data = sub_data, 
                              aes(x = Longitude, y = Latitude, 
                                  fill = mean_last_year,
                                  color = ifelse((mean_last_year < cont[idx,2])|is.na(cont[idx,2]), "black", "red")), 
                              alpha = .8, size = 5, shape = 21, stroke = 1)+ theme_minimal() +    
                   theme(legend.position = "none") + 
                   ylab("Latitude")+xlab("Longitude") +
                   scale_color_manual(values = c("red" = "red", "black" = "black")) +
                   scale_fill_continuous(high = "#132B43", low = "#56B1F7"),
                 
                 sub_data %>%
                   ggplot(aes(x = Station, y = mean_last_year)) + 
                   geom_col(aes(fill = mean_last_year), width = .6, color = "black", linewidth = .5) +  theme_minimal() +
                   coord_flip() + xlab("") +ylab('fitted mean 2024')+#ylab(mocis_get_unit(var = vars[idx], gen = "CLUP")) + 
                   theme(legend.position = "none", axis.text.x = element_text(angle = 45)) +
                   scale_fill_continuous(high = "#132B43", low = "#56B1F7")
  )
  ggsave(p, filename = paste0(path,"output/",folder,"/figs/", cont[idx,1], "_mean_map.pdf"), width = 8, height = 5)

}
for (idx in (1:q)){
  sub_data <- mf |> filter(Cont_short==cont[idx,1])
  p <- plot_grid(ggplot(world_map) + 
                   geom_sf(color = "white", fill = "grey") + 
                   annotation_north_arrow(location = "tl", height = unit(0.7, "cm"), width = unit(0.7, "cm")) +
                   annotation_scale() +
                   coord_sf(xlim = c(8, 25), ylim = c(54, 70), expand = FALSE) +
                   geom_point(data = sub_data, 
                              aes(x = Longitude, y = Latitude, 
                                  fill = recent_change), 
                              alpha = .8, size = 5, shape = 21, stroke = 1)+ theme_minimal() + 
                   scale_fill_gradient2(high = muted("red"), mid = "white", low = muted("blue")) +
                   theme(legend.position = "none") + 
                   ylab("Latitude")+xlab("Longitude"),
                 
                 sub_data %>%
                   ggplot(aes(x = Station, y = recent_change)) + 
                   geom_col(aes(fill = recent_change), width = .6, color = "black",  linewidth = .5) +  theme_minimal() +
                   coord_flip()  +xlab("") +ylab("yearly relative change, %") + 
                   theme(legend.position = "none", axis.text.x = element_text(angle = 45)) +
                   scale_fill_gradient2(high = muted("red"), mid = "white", low = muted("blue")))
  
  ggsave(p, filename = paste0(path,"output/",folder,"/figs/", cont[idx,1], "_rate_map.pdf"), width = 8, height = 5)

}

##############################-
## Contents for appendix OBS FRESHWATER VERSION !!!!! ----
##############################-

group_order <- c('Metals','Chlorinated pesticides','Chlorobiphenyls', "Dioxins", "Organobromines", "Organofluorines")
fish_order <- c('PERC','SALV','ESOX')
var_order <- c("AG", "AL", "AS", "CD", "CR", "CU", "HG", "NI", "PB", "SE", "ZN", 
               "DDT", "DDD", "DDE", "AHCH", "BHCH", "LINDAN", "HCB", 
               "CB28", "CB52", "CB101", "CB118", "CB153", "CB180", 
               "CB77", "CB81", "CB126", "CB169", "CB123", "CB114", "CB105", 
               "CB167", "CB156", "CB157", "CB189", "CB138","TEQDLP", "TCDF", "PECDF1", 
               "PECDF2", "HXCDF1", "HXCDF2", "HXCDF3", "HXCDF4", "HPCDF1", "HPCDF2", 
               "OCDF", "TCDD", "PECDD", "HXCDD1", "HXCDD2", "HXCDD3", "HPCDD", 
               "OCDD", "TEQDF", "BDE28","BDE47", "BDE99", "BDE100", "BDE153", 
               "BDE154", "HBCD","SUMPBDE", "PFHXA", "PFHPA", "PFOA", "PFNA", 
               "PFDA", "PFUNDA", "PFDODA", "PFTRDA", "PFTEDA", "PFPEDA", "LPFBS", 
               "PFHXS", "BPFHXS","LPFOS", "BPFOS", "PFOS", "LPFDS", "BPFDS", "PFDS", 
               "LFOSA", "BFOSA", "FOSA") #

tables_A <- read.csv(paste(path,"output/",folder,"/biota_summary.csv", sep='')) |>
  mutate(gen = case_when(
    species == 'Perca fluviatilis' ~ 'PERC',
    species == 'Salvelinus alpinus' ~ 'SALV',
    species == 'Esox lucius' ~ 'ESOX'
  ),
  var_name = factor(determinand,levels = var_order),
  group = factor(determinand_group, levels = group_order),
  gen = factor(gen, levels = fish_order)) |>
  rename(var = 'determinand') |>
  select(gen, var, var_name, group) |>
  arrange(group, var_name,gen) |>
  distinct(gen, var, var_name, group) |>
  group_by(group) |>
  mutate(
    group_order = match(group, group_order),
    var_order = dense_rank(var_name)
  ) |>
  ungroup()


write.csv(tables_A, "<path-removed>/MCOM2025/MCOM25_report/Contents_for_mcom_appendix_25.csv")  
