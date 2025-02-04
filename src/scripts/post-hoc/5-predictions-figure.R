####### Script Information ########################
# Brandon P.M. Edwards
# Multi-species QPAD Detectability
# posthoc/5-predictions-figure.R
# Created December 2023
# Last Updated August 2024

####### Import Libraries and External Files #######

library(cmdstanr)
library(plyr)
library(ggplot2)
library(ggpubr)
library(ggrepel)
theme_set(theme_pubclean())

####### Read Data #################################

rem_model <- readRDS("output/model_runs/removal_predictions.RDS")
load("data/generated/removal_stan_data_pred.rda")
dis_model <- readRDS("output/model_runs/distance_predictions.RDS")
load("data/generated/distance_stan_data_pred.rda")

traits <- read.csv("data/raw/traits.csv")
binomial <- read.csv("data/generated/binomial_names.csv")

####### Removal Model #############################

# Extract log_phi summary statistics from full Stan model runs
rem_summary <- rem_model$summary("log_phi")

# Add species names to these summaries
rem_summary$Code <- removal_stan_data_pred$sp_all

# Get data sample size for all species and add to summary
species_n <- data.frame(table(removal_stan_data_pred$species))
names(species_n) <- c("index", "N")
rem_summary$index <- seq(1, nrow(rem_summary))
rem_summary$N <- 0
for (i in 1:nrow(species_n))
{
  rem_summary[which(rem_summary$index == species_n$index[i]), "N"] <-
    species_n$N[i]
}

# Add binomial names
rem_summary <- dplyr::left_join(x = rem_summary, y = binomial[, c("Code", "Scientific_BT")],
                                by = "Code")
rem_summary$Scientific_BT <- gsub(x = rem_summary$Scientific_BT, pattern = " ", replacement = "_")

# Add traits
rem_summary <- dplyr::left_join(x = rem_summary, y = traits[, c("Code", "Migrant")],
                                 by = "Code")

sp <- c("LEPC", "SPOW", "BITH", "LCTH", 'HASP', 'TRBL', 'KIWA')

to_plot <- rem_summary[which(rem_summary$Code %in% sp), ]
to_plot <- to_plot[match(sp, to_plot$Code), ]

species_vars <- to_plot$variable

other_sp_df <- data.frame(Species = character(),
                          mean = numeric(),
                          Alpha = numeric())
phylo <- removal_stan_data_pred$phylo_corr
for (s in sp)
{
  sci_name <- rem_summary[which(rem_summary$Code == s), ]$Scientific_BT
  migrant <- rem_summary[which(rem_summary$Code == s), ]$Migrant
  
  alpha_df <- data.frame(Sci_Name = dimnames(phylo)[[1]],
                         Alpha = phylo[sci_name, ])
  

  alpha_df <- merge(alpha_df, rem_summary[which(rem_summary$Migrant == migrant &
                                                  (rem_summary$Code %in% sp) == FALSE), 
                                          c("mean", "Scientific_BT")],
                    by.x = "Sci_Name", by.y = "Scientific_BT")
  alpha_df$mean <- exp(alpha_df$mean)
  alpha_df$Species <- rep(s, times = nrow(alpha_df))
  
  other_sp_df <- rbind(other_sp_df,
                       alpha_df[, c("Species", "mean", "Alpha")])
}

other_sp_df <- other_sp_df[which(other_sp_df$Alpha > 0.001), ]

to_plot$Code <- factor(to_plot$Code, levels = sp)

removal_plot <- ggplot(data = to_plot, aes(x = Code, y = exp(mean))) +
  geom_point(data = other_sp_df, aes(y = mean, x= Species, alpha = Alpha), size = 0.5, position=position_jitter(width = 0.2)) +
  geom_point(size = 4, color = "darkred") +
  geom_errorbar(aes(ymin = exp(q5), ymax = exp(q95)), width=.1, color = "darkred") +
  ylim(0,1) +
  xlab("Predicted Cue Rate") + 
  ylab("Species") +
  theme(legend.position = "none") +
  NULL

####### Distance Model ############################

# Extract log_phi summary statistics from full Stan model runs
dis_summary <- dis_model$summary("log_tau")

# Add species names to these summaries
dis_summary$Code <- distance_stan_data_pred$sp_all

# Get data sample size for all species and add to summary
species_n <- data.frame(table(distance_stan_data_pred$species))
names(species_n) <- c("index", "N")
dis_summary$index <- seq(1, nrow(dis_summary))
dis_summary$N <- 0
for (i in 1:nrow(species_n))
{
  dis_summary[which(dis_summary$index == species_n$index[i]), "N"] <-
    species_n$N[i]
}

# Add binomial names
dis_summary <- dplyr::left_join(x = dis_summary, y = binomial[, c("Code", "Scientific_BT")],
                                by = "Code")
dis_summary$Scientific_BT <- gsub(x = dis_summary$Scientific_BT, pattern = " ", replacement = "_")

# Add traits
dis_summary <- dplyr::left_join(x = dis_summary, y = traits[, c("Code", "Migrant", "Habitat",
                                                                "Mass", "Pitch")],
                                by = "Code")
dis_summary$MigHab <- paste0(dis_summary$Migrant, "-", dis_summary$Habitat)

sp <- c("LEPC", "SPOW", "BITH", "LCTH", 'HASP', 'KIWA')

to_plot <- dis_summary[which(dis_summary$Code %in% sp), ]
to_plot <- to_plot[match(sp, to_plot$Code), ]

species_vars <- to_plot$variable

other_sp_df <- data.frame(Species = character(),
                          mean = numeric())

for (s in sp)
{
  trait <- dis_summary[which(dis_summary$Code == s), ]$MigHab
  pitch <- dis_summary[which(dis_summary$Code == s), ]$Pitch
  mass <- dis_summary[which(dis_summary$Code == s), ]$Mass
  
  temp_df <- dis_summary[which(dis_summary$MigHab == trait &
                                 (dis_summary$Code %in% sp) == FALSE &
                                 (dis_summary$Mass >= mass*0.6 & dis_summary$Mass <= mass*1.4) &
                                 (dis_summary$Pitch >= pitch*0.6 & dis_summary$Pitch <= pitch*1.4)), ]
  
  other_sp_df <- rbind(other_sp_df,
                       data.frame(Species = rep(s, times = nrow(temp_df)),
                                  mean = exp(temp_df$mean) * 100))
}

to_plot$Code <- factor(to_plot$Code, levels = sp)

distance_plot <- ggplot(data = to_plot, aes(x = Code, y = exp(mean) * 100)) +
  geom_point(data = other_sp_df, aes(y = mean, x= Species), size = 0.5, position=position_jitter(width = 0.2)) +
  geom_point(size = 4, color = "darkred") +
  geom_errorbar(aes(ymin = exp(q5) * 100, ymax = exp(q95) * 100), width=.1, color = "darkred") +
  xlab("Predicted EDR") + 
  ylab("Species") +
  ylim(0,600) +
  theme(legend.position = "none") +
  NULL

####### Output ####################################

tiff(filename = "output/plots/predictions_figure.tiff",
     width = 6, height = 6, units = "in", res = 600)
ggarrange(removal_plot, distance_plot, nrow = 2, labels = c("A", "B"))
dev.off()

png(filename = "output/plots/predictions_figure.png",
     width = 6, height = 6, units = "in", res = 600)
ggarrange(removal_plot, distance_plot, nrow = 2, labels = c("A", "B"))
dev.off()
