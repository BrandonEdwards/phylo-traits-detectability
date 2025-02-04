####### Script Information ########################
# Brandon P.M. Edwards
# Multi-species QPAD Detectability
# 6-distance-kfold-cv.R
# Created October 2023
# Last Updated May 2024

####### Import Libraries and External Files #######

library(cmdstanr)

source("src/functions/generate-distance-inits.R")

####### Load Data #################################

load("data/generated/distance_stan_data_cv.rda")
cv_folds <- read.csv("data/generated/distance_cv_folds.csv")

####### Set Constants #############################

# Stan settings
n_iter <- 2000
n_warmup <- 1000
n_chains <- 4
refresh <- 10
threads_per_chain <- 3
dis_data <- distance_stan_data_cv # lazy

####### Data Wrangling ############################

ms_model <- cmdstan_model(stan_file = "models/distance_cp.stan",
                          cpp_options = list(stan_threads = TRUE))

ss_model <- cmdstan_model(stan_file = "models/distance_single.stan",
                          cpp_options = list(stan_threads = TRUE))

####### Run Cross Validation ######################

for (i in 1:max(cv_folds$cv_fold))
{
  indices_to_drop <- which(cv_folds$cv_fold == i)
  
  stan_cv_data <- list(n_samples = dis_data$n_samples - length(indices_to_drop),
                       n_species = dis_data$n_species,
                       max_intervals = dis_data$max_intervals,
                       species = dis_data$species[-indices_to_drop],
                       abund_per_band = dis_data$abund_per_band[-indices_to_drop, ],
                       bands_per_sample = dis_data$bands_per_sample[-indices_to_drop],
                       max_dist = dis_data$max_dist[-indices_to_drop, ],
                       n_mig_strat = dis_data$n_mig_strat,
                       mig_strat = dis_data$mig_strat,
                       n_habitat = dis_data$n_habitat,
                       habitat = dis_data$habitat,
                       mass = dis_data$mass[,1],
                       pitch = dis_data$pitch[,1],
                       sp_all = dis_data$sp_all)
  
  # Check to see if we can drop any training columns (i.e. if bands per sample is smaller)
  if (max(stan_cv_data$bands_per_sample) < stan_cv_data$max_intervals)
  {
    max_intervals <- max(stan_cv_data$bands_per_sample)
    
    stan_cv_data$max_intervals <- max_intervals
    stan_cv_data$abund_per_band <- stan_cv_data$abund_per_band[, 1:max_intervals]
    stan_cv_data$max_dist <- stan_cv_data$max_dist[, 1:max_intervals]
  }
  
  stan_cv_data$grainsize <- 1
  stan_cv_data$max_dist <- stan_cv_data$max_dist / 100
  
  inits <- generate_distance_inits(n_chains = n_chains,
                                   sp_list = stan_cv_data$sp_all,
                                   napops_skip = NULL,
                                   param = "cp")
  stan_cv_data$sp_all <- NULL
  
  stan_run_ms <- ms_model$sample(
    data = stan_cv_data,
    iter_warmup = n_warmup,
    iter_sampling = n_iter,
    chains = n_chains,
    parallel_chains = n_chains,
    refresh = refresh,
    threads_per_chain = threads_per_chain,
    init = inits
  )
  stan_run_ms$save_object(file = paste0("output/model_runs/cv_distance/ms-vs-ss/ms_fold_",
                                      i,
                                      ".RDS"))
  
  stan_cv_data$n_mig_strat <- NULL
  stan_cv_data$mig_strat <- NULL
  stan_cv_data$n_habitat <- NULL
  stan_cv_data$habitat <- NULL
  stan_cv_data$mass <- NULL
  stan_cv_data$pitch <- NULL
  
  stan_run_ss <- ss_model$sample(
    data = stan_cv_data,
    iter_warmup = n_warmup,
    iter_sampling = n_iter,
    chains = n_chains,
    parallel_chains = n_chains,
    refresh = refresh,
    threads_per_chain = threads_per_chain,
    init = inits
  )
  stan_run_ss$save_object(file = paste0("output/model_runs/cv_distance/ms-vs-ss/ss_fold_",
                                        i,
                                        ".RDS"))
}
