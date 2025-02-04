####### Script Information ########################
# Brandon P.M. Edwards
# Multi-species QPAD Detectability
# 4-removal-prior-check.R
# Created May 2023
# Last Updated May 2023

####### Import Libraries and External Files #######

library(MASS)
library(ggplot2)
library(ggpubr)
theme_set(theme_pubclean())

####### Load Data #################################

load("data/generated/removal_stan_data.rda")

####### Set Constants #############################

removal_stan_data$lambda <- 0.79
n_sims <- 100

####### Prior Predictive Check ####################

phylo_corr_pl <- removal_stan_data$phylo_corr * removal_stan_data$lambda
for (i in 1:dim(phylo_corr_pl)[1])
{
  phylo_corr_pl[i,i] <- 1
}

sigma <- rexp(n = n_sims, rate = 5)
pdf(file = "output/prior_predictive_check/removal/sigma.pdf")
print(ggplot(data = data.frame(sigma), aes(x = sigma)) +
        geom_histogram(bins = 20) +
        NULL)
dev.off()

mu_mig_strat <- matrix(data = NA,
                       ncol = removal_stan_data$n_mig_strat,
                       nrow = n_sims)
for (i in 1:removal_stan_data$n_mig_strat)
{
  mu_mig_strat[,i] <- rnorm(n_sims, mean = -1, sd = 0.01)
}
pdf(file = "output/prior_predictive_check/removal/mu_mig_strat.pdf")
to_plot <- data.frame(Value = c(mu_mig_strat[,1],
                                mu_mig_strat[,2]),
                      Mig_Strat = c(rep("Resident", 100),
                                    rep("Migrant", 100)))
for (i in unique(to_plot$Mig_Strat))
{
  print(ggplot(data = to_plot[which(to_plot$Mig_Strat == i), ],
               aes(x = Value)) +
          geom_histogram(bins = 20) +
          xlab(i) +
          #xlim(floor(min(to_plot$Value) - 1), ceiling(max(to_plot$Value) + 1)) +
          NULL)
}
dev.off()

mu <- matrix(data = NA, nrow = n_sims, ncol = removal_stan_data$n_species)
pdf(file = "output/prior_predictive_check/removal/mu.pdf")
for (s in 1:removal_stan_data$n_species)
{
  mu[,s] <- mu_mig_strat[, removal_stan_data$mig_strat[s]]
  to_plot <- data.frame(Value = mu[,s])
  print(ggplot(data = to_plot, aes(x = Value)) +
          geom_histogram(bins = 20) +
          xlab(dimnames(phylo_corr_pl)[[1]][s]) +
          xlim(floor(min(mu) - 1), ceiling(max(mu) + 1)) +
          NULL)
}

dev.off()

log_phi <- matrix(data = NA, nrow = n_sims, ncol = removal_stan_data$n_species)
for (i in 1:n_sims)
{
  log_phi[i,] <- MASS::mvrnorm(n = 1, mu = mu[i,],
                               Sigma = phylo_corr_pl * sigma[i])
}

pdf(file = "output/prior_predictive_check/removal/log_phi.pdf")
for (s in 1:removal_stan_data$n_species)
{
  to_plot <- data.frame(Value = (log_phi[,s]))
  print(ggplot(data = to_plot, aes(x = Value)) +
          geom_histogram(bins = 20) +
          xlab(dimnames(phylo_corr_pl)[[1]][s]) +
          xlim(floor(min(log_phi) - 1), ceiling(max(log_phi) + 1)) +
          NULL)
}
dev.off()

pdf(file = "output/prior_predictive_check/removal/phi.pdf")
phi <- exp(log_phi)
for (s in 1:removal_stan_data$n_species)
{
  to_plot <- data.frame(Value = (phi[,s]))
  print(ggplot(data = to_plot, aes(x = Value)) +
          geom_histogram(bins = 20) +
          xlab(dimnames(phylo_corr_pl)[[1]][s]) +
          #xlim(0, 10) +
          NULL)
}
dev.off()