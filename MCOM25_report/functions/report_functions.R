# Report functions modified Anne S 2024 for MCoM ----

# Heatmap ----

MCoM_heatmap <- function(data, trunc = 15, grp = "all", corder=FALSE){
  if (grp != "all"){
    data <- filter(data, substance_group == grp)
  }
  data |>
  ggplot(aes(x = factor(contaminant,level=corder), y = fct_reorder(station_name, -(-1)^(longitude > 13.6)*latitude))) + 
  geom_tile(aes(fill = ifelse(abs(lm_slope) > trunc, trunc*sign(lm_slope), lm_slope))) + 
  scale_fill_gradient2(limits = c(-trunc, trunc), low = muted("blue"), mid = "white", high = muted("red"), na.value = 'white') + 
  geom_text(aes(label = stars,  color = (abs(lm_slope) > 10)), size = 3, show.legend = FALSE) + 
  scale_color_manual(values = c("black", "white")) +  
  xlab("") + ylab("")+
  facet_col(vars(factor(species_EN, level=c("Atlantic herring", "Atlantic cod", "European perch", "Viviparous eelpout",
                                            "Blue mussel", "Common guillemot", "Common Tern", "Eurasian oystercatcher"))), scales = "free_y", space = "free") + 
  theme(legend.position = "top", 
        panel.grid.major = element_blank(), 
        panel.grid.minor = element_blank(), 
        axis.text.x = element_text(angle = 90, vjust = 0.5, hjust=1),
        legend.title = element_blank()) +
  scale_x_discrete(expand=c(0,0)) +
  scale_y_discrete(expand=c(0,0)) +
  ggtitle(ifelse(grp == "all", "", paste0(grp, ", yearly percent change (2014-2023)"))) ## for function!
}
## Model fitting ----

common_intercept <- function(fit.lm){
  theta <- coef(fit.lm)
  d <- length(theta)
  D <- cbind(1, diag(d - 1))
  D[1, 2] <- 0
  intercepts <- t(D %*% theta)
  Sigma <- D %*% vcov(fit.lm) %*% t(D)
  w <- diag(Sigma)
  sum(intercepts/w)/sum(1/w)
}

print_ci <- function(estimate, lower, upper, dec = 2) {
  ifelse(is.numeric(estimate), paste0(round(estimate, dec), 
                                      " (", round(lower, dec), ", ", round(upper, 
                                                                           dec), ")"), "")
}

slope2rate <- function(x) {100*(exp(x) -1)}



## basin plot ----

basin_plot <- function(data,  grp = "all", cols = 2, unit = ""){
  if (grp != "all"){
    data <- filter(data, group == grp)
  }
  level = c('Bothnian Bay','Bothnian Sea','Northern Baltic Proper','Southern Baltic Proper','Kattegat')
  #ggplot(data, aes(x = YEAR, y = CONC, color = basin, fill = basin)) +
  ggplot(data, aes(x = year, y = CONC, color = factor(basin, level = level), fill = factor(basin, level=level))) +
    geom_line(data = filter(data), linetype="blank") +  
    geom_ribbon(data = filter(data, p_vs_full > .05), aes(ymin = LOWER, ymax = UPPER), alpha = .15, colour = NA)+
    geom_line(data = filter(data, p_vs_full > .05)) +
    geom_line(data = filter(data, p_vs_full <= .05), linetype = "dashed") +
    facet_wrap(~var_name, scales = "free_y", ncol = cols) +
    #scale_y_continuous(limits = c(0, NA), expand = expand_scale(mult = c(0, 0.1))) + #ALS OCT 2024
    scale_y_continuous(limits = c(0, NA), expand = expansion(mult = c(0, 0.1))) +
    scale_x_continuous(breaks=seq(2014, 2023, 2)) + #ALS Nov 2020, Oct 2024
    # theme_bw() +
    theme(legend.position = "top", legend.title = element_blank(),           
          panel.grid.major = element_blank(), 
          panel.grid.minor = element_blank(), 
          panel.background = element_blank()) + 
    ylab(unit) + xlab("") +
    ggtitle(ifelse(grp == "all", "", paste0(grp, ", fitted trends (2014-2023)")))
}

