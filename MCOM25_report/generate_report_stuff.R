# Figures for marine overview report ----
# based on MCoM database

## libraries ----
library(tidyverse)
library(openxlsx)
library(readxl)
library(ggforce)
library(ggrepel)
library(rnaturalearth)
library(rnaturalearthdata)
library(sf)
library(scales)
library(cowplot)

### install new MCoM version if needed ----
#devtools::install_local("<path-removed>/Yosrbase/mcomDb", force = TRUE)
library(mcomDb)

## read in data ----
#MCoM <- mcomDb::MCoM |> mutate(d13C = as.numeric(d13C), d15N = as.numeric(d15N),uncertainty = as.numeric(uncertainty),
#MCoM <- MCoM |> mutate(d13C = as.numeric(d13C), d15N = as.numeric(d15N),uncertainty = as.numeric(uncertainty),
#                               C_dw_percentage = as.numeric(C_dw_percentage), N_dw_percentage = as.numeric(N_dw_percentage),
#                       total_length=as.numeric(total_length),age=as.numeric(age), weight=as.numeric(weight),
#                       dry_weight_percentage=as.numeric(dry_weight_percentage),fat_percentage = as.numeric(fat_percentage ))



report_year <- 2023 # also change year range in "report_functions.R"

# Utility functions ----
source("functions/report_functions.R")

## Function to divide LOQ by the SQR of 2 ####
M_sqrt <- function(x)(x = if_else(x<0,(abs(x)/sqrt(2)), x)) 


# Station data for map and basin ----
station_table <- read_excel("stations.xlsx")  #NEED TO REPLACE WITH NEW FILE
#raw_data <- read.csv("../MCOM24_rawdata_SGUapproach/raw_data_MCoM_2024.csv")
raw_data <- read.csv("../MCOM24_rawdata_SGUapproach/raw_data_MCoM_2024_all_v4.csv") 

MCoM_data <- MCoM |> bind_rows(raw_data) |>
  group_by(station_name) |>
  fill(latitude, longitude, .direction = "down") |>
  ungroup() |>
  mutate(value = if_else(is_censored==TRUE, value*(-1), value)) |>
  mutate_at('value', M_sqrt) |>
  ### NB ###
  filter(contaminant!='Bi') 
  #mutate(value = case_when((substance_group=='Pesticides'|substance_group=='Solvents')&year==2022~value/1000, 
  #                         substance_group=='PCBs'&year==2022&contaminant!='CB118' ~value/1000,
  #                         TRUE~value))

##
##  Station map ----
##

## Backgrounds for station map
world_map <- ne_countries(scale = "medium", returnclass = "sf") %>% 
  st_crop(c(xmin=1, xmax=36, ymin=53, ymax=70))

## Map
map <- ggplot(world_map) + 
  geom_sf(color = "white", aes(fill = (name == "Sweden"))) + 
  geom_sf(color = "grey90", size = 0) +
  theme_minimal() +
  coord_sf(xlim = c(1, 36), ylim = c(53, 70), expand = FALSE) +
  geom_text_repel(data = filter(station_table, basin != "Kattegat"), aes(x = long, y = lat, label = paste0(station, " (", collected, ")")), 
                  size = 2.5, nudge_x = 25- filter(station_table, basin != "Kattegat")$long, direction = "y", hjust = 0,
                  segment.size  = 0.5,
                  segment.color = "grey50")  +
  geom_text_repel(data = filter(station_table, basin == "Kattegat"), aes(x = long, y = lat, label = paste0(station, " (", collected, ")")), 
                  size = 2.5, nudge_x = 2 - filter(station_table, basin == "Kattegat")$long, direction = "y", hjust = 1,
                  segment.size  = 0.5,
                  segment.color = "grey50")  +
  geom_point(data = station_table, aes(x = long, y = lat, color = basin), size = 2) +
  theme(legend.position.inside = c(0.18, .87), legend.title = element_blank()) + xlab("") + ylab("") +
  scale_fill_manual(values = c("grey90", "grey"), guide = 'none')

ggsave(map, filename = "report_figs/map.png", dpi = 600, width = 5, height = 5)

##
## Basin plots ----
##

# Contaminants to be included in basin-level analysis
basin_contaminants <- c("BDE47", "CB118", "CB153", "Cd", "Cu", "DDE", "LFOSA", "HBCD", "HCB", "Hg", 
                        "Pb", "LPFOS", "PFUNDA", "TCDF", "PECDF2","HXCDF4","OCDF")#"OCDD", "TCDD")

# Data wrangling
basin_data <- filter(MCoM_data, contaminant %in% basin_contaminants,
                     species == "Clupea harengus") |>
  filter(year > 2014) |>
  filter(season == 'Autumn') |>
  left_join(station_table, by = c("station_name" = "station_E")) |>
  mutate(value = if_else(contaminant == 'CB118', value/(10^6), value))

# Model fitting
basin_fits <- basin_data |> 
  group_by(contaminant, basin) |> 
  nest() |> 
  mutate(lm_fit = map(data, ~lm(log(value) ~ station_name + year, data = .x)),
         lm_fit_full = map(data, ~lm(log(value) ~ station_name * year, data = .x)),
         p_vs_full = map2_dbl(lm_fit, lm_fit_full, ~anova(.x, .y)$"Pr(>F)"[2]),
         lm_summary = map(lm_fit, summary),
         lm_intercept = map_dbl(lm_fit, common_intercept),
         lm_slope = map_dbl(lm_fit, ~coef(.x)["year"]),
         lm_slope_se = map_dbl(lm_fit, ~vcov(.x)["year", "year"] %>% sqrt()),
         lm_slope_CI = map(lm_fit, ~confint(.x)["year", ]),
         lm_slope_upper = map_dbl(lm_slope_CI, ~.x[2]),
         lm_slope_lower = map_dbl(lm_slope_CI, ~.x[1]),
         lm_predict = pmap(list(lm_intercept, lm_slope, lm_slope_lower, lm_slope_upper), 
                           ~tibble(year = seq(2014, 2023, by = 0.5), CONC = exp(..1 + ..2 * year),
                                   UPPER = exp(..1 + ..2 * year + (..4 - ..2) * abs(year - mean(year))),
                                   LOWER = exp(..1 + ..2 * year + (..3 - ..2) * abs(year - mean(year))))),
         table_ci = pmap_chr(list(slope2rate(lm_slope), slope2rate(lm_slope_lower), slope2rate(lm_slope_upper), p_vs_full), 
                             ~if_else(..4 > .05, print_ci(..1, ..2, ..3), as.character(round(..1, 2))))
  ) |> 
  ungroup() |>
  left_join(read_excel("variables.xlsx"), by = "contaminant") |>
  mutate(var_name = fct_reorder(var_name, group_order * 1000 + var_order)) |>
  select(var_name, contaminant, group, basin, lm_intercept, lm_slope, lm_slope_CI, lm_slope_lower, lm_slope_upper, p_vs_full, lm_predict, table_ci, data)

# Group-wise plots of concentrations
basin_plot_data <- unnest(basin_fits, lm_predict)
basin_met <- basin_plot(basin_plot_data, grp = "Metals", unit = bquote("Concentration: Hg - other metals,"~n*g/g - ~mu*g/g))
basin_pd <- basin_plot(basin_plot_data, grp = "Polychlorinated Dibenzodioxins /-furans", unit = bquote("Concentration,"~p*g/g))
basin_pb <- basin_plot(basin_plot_data, grp = "Polychlorinated Biphenyls", unit = bquote("Concentration,"~mu*g/g))
basin_cp <- basin_plot(basin_plot_data, grp = "Chlorinated Pesticides", unit = bquote("Concentration,"~mu*g/g))
basin_bfr <- basin_plot(basin_plot_data, grp = "Brominated Flame Retardants", unit = bquote("Concentration,"~n*g/g))
basin_ps <- basin_plot(basin_plot_data, grp = "Perfluoroalkyl Substances", unit = bquote("Concentration,"~n*g/g))

h <-  4
w <-  7
ggsave(basin_met, filename  = "report_figs/basin_met.png", dpi = 600, width = w, height = h * 1.8)
ggsave(basin_pd, filename  = "report_figs/basin_pd.png", dpi = 600, width = w, height = h * 1.8)
ggsave(basin_pb, filename  = "report_figs/basin_pb.png", dpi = 600, width = w, height = h)
ggsave(basin_cp, filename  = "report_figs/basin_cp.png", dpi = 600, width = w, height = h)
ggsave(basin_bfr, filename  = "report_figs/basin_bfr.png", dpi = 600, width = w, height = h)
#ggsave(basin_ps, filename  = "report_figs/basin_ps.png", dpi = 600, width = w, height = h * 1.8)

ggsave(basin_plot(basin_plot_data, "Perfluoroalkyl Substances", cols = 3, unit = bquote("Concentration,"~n*g/g)), 
       filename = "report_figs/basin_ps3x1.png", dpi= 600, width = w * 1.3, height = h)
#ggsave(basin_plot(basin_plot_data, "Polychlorinated Dibenzodioxins /-furans", cols = 3, unit = bquote("Concentration,"~p*g/g)), 
#       filename = "report_figs/basin_pd3x1.png", width = w * 1.3, height = h)


##
## Basin table ----
## 

basin_fits %>% select(var_name, basin,  table_ci) %>% 
  distinct() %>% 
  pivot_wider(names_from = basin, values_from = table_ci) %>% 
  rename(Contaminant = var_name) %>% 
  write.xlsx(file = "report_figs/basin_table.xlsx")


##
## Heatmaps ----
##

plot_prep <- MCoM_data |>
  filter(!(contaminant %in% c("Sn","Al","Cr","Sb", "AHCH", "BITSI","LINDAN",'CB138and163', 
                              "PFHXA", "PFHPA", "LPFBS",'PFBS', "BPFDS", "LPFDS","PFDS",
                              'BPFHXS','LPFHXS','PFPEDA','PFHXS','PFOS','FOSA'))) |>
  filter(!((station_name == 'Holmoarna') & (species == 'Zoarces viviparus'))) |>
  filter(!((contaminant== 'Cd'|contaminant=='Pb'|contaminant=='Al'|contaminant=='Al') & (class == 'Bird'))) |>
  filter(!((contaminant== 'BHCH'|contaminant=='DDD'|contaminant=='CB28'|contaminant=='CB52') & 
             (class == 'Bird'| species_EN == 'Blue mussel' | 
             species_EN == 'European perch' | species_EN =='Atlantic cod' |
             species_EN =='Viviparous eelpout'))) |>
  filter(!((contaminant=='HCB')& species_EN=='Blue mussel')) |>
  filter(!((contaminant=='DDT') & class == 'Bird')) |>
  filter(contaminant != "CB138") |>
  filter(contaminant != "CB118") |> #check this is the right one
  filter(year >= 2014) |>
  #mutate_at('value', M_sqrt) |>
  mutate(station_name = case_when(
    station_name == 'Angskarsklubb' & season == 'Spring' ~ 'Angskarklubb spring',
    station_name == 'Utlangan' & season == 'Spring' ~ 'Utlangan spring',
    TRUE ~ station_name
  )) |>
  mutate(substance_group = case_when(
    substance_group == 'Solvents' ~ 'Pesticides',
    TRUE ~substance_group
  ))

### bio variables - add dry weight and fat % to long format ----
variables <- c('station_name','year','date','species','contaminant', 'unit','value', 'substance_group',
               'species_EN','latitude','longitude','class')
NRM_ag <- plot_prep |> drop_na(age) |> select(-c(value))  |> rename(value='age') |> 
  mutate(substance_group='Biological data',contaminant='Age, y',unit='y') |> select(all_of(variables))|> unique() |>
  filter(species!='Uria aalge', species!='Haematopus ostralegus', species!='Sterna hirundo',species_EN!='Blue mussel')
NRM_w <- plot_prep |> drop_na(weight) |> select(-c(value))  |> rename(value='weight') |> filter(species_EN!='Blue mussel') |>
  mutate(substance_group='Biological data',contaminant='Weight, g',unit='g') |> select(all_of(variables))|> unique() |> 
  # REMOVE NEXT YEAR 2025!!! Incorrect weights for birds, needs to be corrected through resubmitssion to SGU
  filter(class!='Bird') ## END
NRM_tl <- plot_prep |> drop_na(total_length) |> 
  # REMOVE NEXT YEAR 2025!!! Incorrect lengths for Tjärnö eggs, needs to be corrected in MCoM
  mutate(total_length = case_when(
    species == 'Haematopus ostralegus' & year <= 2020 ~ total_length/10,
    species == 'Sterna hirundo' & year <= 2020 ~ total_length/10,
    TRUE ~ total_length
  )) |> ## END
  select(-c(value))  |> rename(value='total_length') |> filter(species_EN!='Blue mussel') |>
  mutate(substance_group='Biological data',contaminant='Length, cm',unit='cm') |> select(all_of(variables))|> unique()

#NRM_dw <- plot_prep |> drop_na(dry_weight_percentage) |> select(-c(value))  |> rename(value='dry_weight_percentage') |> 
#  mutate(substance_group='Biological data',contaminant='dry weight, %',unit='%') |> unique()
NRM_fp <- plot_prep |> drop_na(fat_percentage) |> select(-c(value))  |> rename(value='fat_percentage') |> filter(species_EN!='Blue mussel') |>
  mutate(substance_group='Biological data',contaminant='Fat, %',unit='%')|> select(all_of(variables)) |> unique()

#test2 <- plot_prep |> filter(substance_group=='PCBs') |> distinct(contaminant)

test <- plot_prep |> filter(contaminant=='HBCD')
#test <- NRM_tl #|> filter(contaminant=='PECDF2')
ggplot(test, aes(year, value))+
 geom_point()+
geom_smooth(method = 'lm', alpha = .1) +
 facet_wrap(~station_name, nrow=3, scales = "free_y")
  

plot_data <- plot_prep |> 
  bind_rows(NRM_ag,NRM_w,NRM_tl,NRM_fp) |>
  left_join(read_excel('variables.xlsx'), by = 'contaminant')  |> 
  group_by(station_name,substance_group,contaminant, species) |> 
  nest() |> 
  mutate(lm_fit = map(data, ~lm(log(value) ~  year, data = .x)),
         lm_summary = map(lm_fit, summary),
         lm_slope = 100*(map_dbl(lm_fit, ~coef(.x)["year"])), # percent change
         p_value = map_dbl(lm_summary, ~.x$coefficients["year", "Pr(>|t|)"]),
         stars = case_when(p_value > 0.05 ~ "", (p_value <= 0.05) & (p_value > 0.01) ~ "*", 
                           (p_value <= 0.01) & (p_value > 0.001) ~ "**", p_value <= 0.001 ~ "***")
  ) |> 
  unnest(data) |> 
  select(substance_group, contaminant, species, species_EN, station_name, lm_slope,  stars, latitude, longitude) |>
  distinct() |>
  left_join(read_excel("variables.xlsx"), by = "contaminant") |>
  mutate(station_name = as.factor(station_name))

heat_bio <- MCoM_heatmap(plot_data, grp = "Biological data", corder=c('Age, y','Weight, g','Length, cm', 'Fat, %')) #%>% filter(gen != "MYTI"), grp = "Biological data") # NOT WORKING!!!
heat_met <- MCoM_heatmap(plot_data, grp = "Metals", corder = c('Hg','Cd','Pb','Cu','Ag','As','Ni','Se','Zn'))
heat_pd <- MCoM_heatmap(plot_data, grp = "Dioxins and furans", 
                        corder = c('TCDF','PECDF1','PECDF2','HXCDF1','HXCDF2','HXCDF3','HXCDF4','HPCDF1','HPCDF2','OCDF',
                                   'TCDD','PECDD','HXCDD1','HXCDD2','HXCDD3','HPCDD','OCDD'))
heat_pb <- MCoM_heatmap(plot_data, grp = "PCBs", corder=c('CB28','CB52','CB101','CB118_ndl','CB153','CB180',
                                                          'CB77','CB81','CB126','CB169','CB123','CB114','CB105','CB167','CB156','CB157','CB189'))
heat_cp <- MCoM_heatmap(plot_data, grp = "Pesticides", corder=c('DDT','DDD','DDE','BHCH','HCB'))
heat_bfr <- MCoM_heatmap(plot_data, grp = "BFRs",corder=c('BDE28','BDE47','BDE99','BDE100','BDE153','BDE154','HBCD'))
heat_ps <- MCoM_heatmap(plot_data, grp = "PFAS", corder = c('PFOA','PFNA','PFDA','PFUNDA','PFDODA','PFTRDA','PFTEDA','LPFOS','BPFOS','LFOSA','BFOSA'))
heat_pah <- MCoM_heatmap(plot_data, grp = "PAH", corder = c('NAP','ACNE','FLE','PA','ANT','FLU','PYR','BAA','CHR','BBF','BKF','BAP','BGHIP','DBAHA','ICDP'))
heat_to <- MCoM_heatmap(plot_data, grp = "Organotin compounds")


ggsave(heat_bio, filename = "report_figs/heat_bio.png", width = 8, height = 9, dpi = 600)
ggsave(heat_met, filename = "report_figs/heat_met.png", width = 8, height = 9, dpi = 600)
ggsave(heat_pd, filename = "report_figs/heat_pd.png", width = 8, height = 9, dpi = 600) # FIX NAMES AND SORT - make group_order work!
ggsave(heat_pb, filename = "report_figs/heat_pb.png", width = 8, height = 11, dpi = 600)
ggsave(heat_cp, filename = "report_figs/heat_cp.png", width = 8, height = 9, dpi = 600)
ggsave(heat_bfr, filename = "report_figs/heat_bfr.png", width = 8, height = 9, dpi = 600)
ggsave(heat_ps, filename = "report_figs/heat_ps.png", width = 8, height = 7, dpi = 600)  # FIX NAMES AND SORT
ggsave(heat_pah, filename = "report_figs/heat_pah.png", width = 8, height = 4, dpi = 600) # FIX NAMES
ggsave(heat_to, filename = "report_figs/heat_to.png", width = 8, height = 4, dpi = 600)


##
## Isotopes ----
##

iso_data <- MCoM_data |>
  select(station_name, year, species_EN, specimen_ID, d13C, d15N, C_dw_percentage, N_dw_percentage) |>
  mutate(d13C = d13C - 3.32  + 0.99 * C_dw_percentage / N_dw_percentage) |>
  na.omit() |>
  distinct() |>
  left_join(station_table, by = c("station_name" = "station_E"))# |>
  #mutate(Species = mocis_name_species(GENUS))

level = c('Bothnian Bay','Bothnian Sea','Northern Baltic Proper','Southern Baltic Proper','Kattegat')

sia_plot <- iso_data  %>% 
  group_by(station, year, basin, species_EN) %>% 
  summarise(d13C = mean(d13C), d15N = mean(d15N)) %>% 
ggplot(aes(x = d13C, y = d15N, color  = species_EN)) + 
  geom_point(alpha = .8) +
  stat_ellipse(show.legend = FALSE) +
  facet_wrap(~factor(basin, level=level)) +
  theme(#legend.position.inside = c(.85, .25), 
        legend.title = element_blank(),
        legend.key = element_rect(fill = NA, colour=NA),
        panel.border = element_rect(colour = "lightgrey", fill = NA),
        panel.grid.major = element_blank(), 
        panel.grid.minor = element_blank(), 
        panel.background = element_blank(),
        aspect.ratio = 1) +
  ylab(bquote(delta^{15}*N*","~"\U2030"))+
  xlab(bquote(delta^{13}*C*","~"\U2030")) +
  ggtitle("Stable isotopes")

ggsave(sia_plot, filename = "report_figs/sia_plot_test.png", width = 7, height = 6, dpi = 600)


sia_plot_herring <- iso_data %>% filter(species_EN == "Atlantic herring") %>% 
  group_by(station, year, basin) %>% 
  summarise(d13C = mean(d13C), d15N = mean(d15N)) %>% 
  ggplot(aes(x = d13C, y = d15N, color  = factor(basin, level=level))) +
  geom_point(alpha = .8) +
  stat_ellipse(show.legend = FALSE) +  
  theme(legend.title = element_blank(),
        legend.key = element_rect(fill = NA, colour=NA),
        panel.border = element_rect(colour = "lightgrey", fill = NA),
        panel.grid.major = element_blank(), 
        panel.grid.minor = element_blank(), 
        panel.background = element_blank(),
        aspect.ratio = 1)+
  ylab(bquote(delta^{15}*N*","~"\U2030"))+
  xlab(bquote(delta^{13}*C*","~"\U2030")) +
  ggtitle("Stable isotopes, Herring")

ggsave(sia_plot_herring, filename = "report_figs/sia_plot_herring_test.png", width = 7, height = 6, dpi = 600)

### isotope temporal plot test ----

#tests <- MCoM |> filter(year == 2013) #|>
#  select(station_name, year, species_EN, specimen_ID, d13C, d15N, C_dw_percentage, N_dw_percentage) |>
#  distinct() |>
#  na.omit()

sia_temp <- MCoM_data |>
  select(station_name, year, species_EN, specimen_ID, d13C, d15N, C_dw_percentage, N_dw_percentage) |> # sample_ID?
  mutate(d13C = d13C - 3.32  + 0.99 * C_dw_percentage / N_dw_percentage) |>
  distinct() |>
  na.omit() |>
  left_join(station_table, by = c("station_name" = "station_E")) |>
  group_by(year,species_EN,basin) |>
  summarize(d15N=mean(d15N), d13C = mean(d13C)) |>
  ungroup()

sia_temp_plot_C <- sia_temp |>
  ggplot(aes(x=year,y=d13C,color = factor(basin,level=level))) +
  geom_point()+
  geom_smooth(method = 'lm', alpha = 0) +
  facet_wrap(~species_EN, ncol=2) + 
  theme_classic()+
  ylab(bquote(delta^{13}*C*","~"\U2030"))+
  labs(color = "Basins")

sia_temp_plot_N <- sia_temp |>
  ggplot(aes(x=year,y=d15N,color = factor(basin,level=level))) +
  geom_point()+
  geom_smooth(method = 'lm', alpha = 0) +
  facet_wrap(~species_EN, ncol=2) + 
  theme_classic()+
  ylab(bquote(delta^{15}*N*","~"\U2030"))+ 
  theme(legend.position="none")

sia_temp_plot <- plot_grid(sia_temp_plot_N, sia_temp_plot_C, labels = c('A', 'B'),
                           rel_widths = c(1, 1.4))

ggsave(sia_temp_plot, filename = "report_figs/sia_temp_plot_test.png", width = 11, height = 8, dpi = 600)

