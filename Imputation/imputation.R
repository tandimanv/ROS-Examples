#' ---
#' title: "Regression and Other Stories: Imputation"
#' author: "Andrew Gelman, Jennifer Hill, Aki Vehtari"
#' date: "`r format(Sys.Date())`"
#' output:
#'   html_document:
#'     theme: readable
#'     toc: true
#'     toc_depth: 2
#'     toc_float: true
#'     code_download: true
#' ---

#' Regression-based imputation for the Social Indicators Survey. See
#' Chapter 17 in Regression and Other Stories.
#' 
#' -------------
#' 

#+ setup, include=FALSE
knitr::opts_chunk$set(message=FALSE, error=FALSE, warning=FALSE, comment=NA)
# switch this to TRUE to save figures in separate files
savefigs <- FALSE

#' #### Load packages
library("rprojroot")
root<-has_dirname("ROS-Examples")$make_fix_file()
library("rstanarm")

#' #### Load data
SIS <- read.csv(root("Imputation/data","SIS.csv"))
head(SIS)
summary(SIS)

#' #### Imputation helper functions</br>
#' Create a completed data vector using imputations
impute <- function(a, a_impute) {
  ifelse(is.na(a), a_impute, a)
}
#' Top code function
topcode <- function(a, top) {
  ifelse(a > top, top, a)
}

#' ## Deterministic imputation

#' #### Impute 0 earnings using the logical rule (if worked 0 months and 0 hrs/wk)
SIS$earnings_top <- topcode(SIS$earnings, 100)
SIS$earnings_top[SIS$workhrs_top==0 & SIS$workmos==0] <- 0

#' #### Create a dataset with all predictor variables
n <- nrow(SIS)
SIS_predictors <- SIS[,c("male","over65","white","immig","educ_r","workmos",
                         "workhrs_top","any_ssi","any_welfare","any_charity")]

#' #### Impute subset of earnings that are nonzero:  linear scale
fit_imp_1 <- stan_glm(
  earnings ~ male + over65 + white + immig + educ_r +
              workmos + workhrs_top + any_ssi +
              any_welfare + any_charity,
  data = SIS,
  subset = earnings > 0,
  refresh = 0
)
print(fit_imp_1)
#' point predictions
pred_1 <- colMeans(posterior_linpred(fit_imp_1, newdata = SIS_predictors))  
SIS$earnings_imp_1 <- impute(SIS$earnings, pred_1)

#' #### Impute subset of earnings that are nonzero:  square root scale and topcoding
fit_imp_2 <- stan_glm(
  sqrt(earnings_top) ~ male + over65 + white + immig +
                       educ_r + workmos + workhrs_top + any_ssi +
                       any_welfare + any_charity,
  data = SIS,
  subset = earnings > 0,
  refresh = 0
)
print(fit_imp_2)
#' point predictions
pred_2_sqrt <- colMeans(posterior_linpred(fit_imp_2, newdata = SIS_predictors))  
pred_2 <- topcode(pred_2_sqrt^2, 100)
SIS$earnings_imp_2 <- impute(SIS$earnings_top, pred_2)

#' ## One random imputation

#' #### Linear scale (use fitted model fit_imp_1)
pred_3 <- posterior_predict(fit_imp_1, newdata = SIS_predictors, draws = 1)
SIS$earnings_imp_3 <- impute(SIS$earnings, pred_3)

#' #### Square root scale and topcoding (use fitted model fit_imp_2)
pred_4_sqrt <- posterior_predict(fit_imp_2, newdata = SIS_predictors, draws = 1)
pred_4 <- topcode(pred_4_sqrt^2, 100)
SIS$earnings_imp_4 <- impute(SIS$earnings_top, pred_4)

#' ### 3.  Histograms and scatterplots of data and imputations
#+ eval=FALSE, include=FALSE
if (savefigs) pdf(root("Imputation/figs","impute_hist2.pdf"), height=4, width=5.5)
#+
par(mar=c(3,3,1,1), mgp=c(1.7,.5,0), tck=-.01)
hist(SIS$earnings_top[SIS$earnings>0], breaks=seq(0,100,10), xlab="earnings", ylab="", main="Observed earnings (excluding 0's)")
#+ eval=FALSE, include=FALSE
if (savefigs) dev.off()

#+ eval=FALSE, include=FALSE
if (savefigs) pdf(root("Imputation/figs","impute_hist3.pdf"), height=4, width=5.5)
#+
par(mar=c(3,3,1,1), mgp=c(1.7,.5,0), tck=-.01)
hist(SIS$earnings_imp_2[is.na(SIS$earnings)], breaks=seq(0,100,10),
      xlab="earnings", ylab="", ylim=c(0,48),
      main="Deterministic imputation of earnings")
#+ eval=FALSE, include=FALSE
if (savefigs) dev.off()

#+ eval=FALSE, include=FALSE
if (savefigs) pdf(root("Imputation/figs","impute_hist4.pdf"), height=4, width=5.5)
#+
par(mar=c(3,3,1,1), mgp=c(1.7,.5,0), tck=-.01)
hist(SIS$earnings_imp_4[is.na(SIS$earnings)], breaks=seq(0,100,10),
      xlab="earnings", ylab="", ylim=c(0,48),
     main="Random imputation of earnings")
#+ eval=FALSE, include=FALSE
if (savefigs) dev.off()

#+ eval=FALSE, include=FALSE
if (savefigs) pdf(root("Imputation/figs","impute_scat_1.pdf"), height=4, width=5)
#+
par(mar=c(3,3,2,1), mgp=c(1.7,.5,0), tck=-.01)
plot(range(SIS$earnings_imp_2[is.na(SIS$earnings)]), c(0,100),
      xlab="Regression prediction", ylab="Earnings",
      main="Deterministic imputation", type="n", bty="l")
points(SIS$earnings_imp_2[is.na(SIS$earnings)], SIS$earnings_imp_2[is.na(SIS$earnings)], pch=19, cex=.5)
points(pred_2, SIS$earnings_top, pch=20, col="darkgray", cex=.5)
#+ eval=FALSE, include=FALSE
if (savefigs) dev.off()

#+ eval=FALSE, include=FALSE
if (savefigs) pdf(root("Imputation/figs","impute_scat_2.pdf"), height=4, width=5)
#+
par(mar=c(3,3,2,1), mgp=c(1.7,.5,0), tck=-.01)
plot(range(SIS$earnings_imp_2[is.na(SIS$earnings)]), c(0,100),
      xlab="Regression prediction", ylab="Earnings",
      main="Random imputation", type="n", bty="l")
points(SIS$earnings_imp_2[is.na(SIS$earnings)], SIS$earnings_imp_4[is.na(SIS$earnings)], pch=19, cex=.5)
points(pred_2, SIS$earnings_top, pch=20, col="darkgray", cex=.5)
#+ eval=FALSE, include=FALSE
if (savefigs) dev.off()

#' ## Two-stage imputation model

#' #### Fit the 2 models
fit_positive <- stan_glm((earnings>0) ~ male + over65 + white + immig +
  educ_r + any_ssi + any_welfare + any_charity,
  data=SIS, family=binomial(link=logit), refresh = 0)
print(fit_positive)
fit_positive_sqrt <- stan_glm(sqrt(earnings_top) ~ male + over65 + white + immig +
  educ_r + any_ssi + any_welfare + any_charity,
  data=SIS, subset=earnings>0, refresh = 0)  # (same as fit_imp_2 from above)
print(fit_positive_sqrt)

#' #### Predict the sign and then the earnings (if positive)
# one random imp
pred_sign <- posterior_predict(fit_positive, newdata = SIS_predictors, draws = 1)
# one random imp
pred_pos_sqrt <- posterior_predict(fit_positive_sqrt, newdata = SIS_predictors,
                                   draws = 1)
pred_pos <- topcode(pred_pos_sqrt^2, 100)
SIS$earnings_imp <- impute(SIS$earnings, pred_sign*pred_pos)

#' ## Iterative regression imputation

#' #### Starting values
random_imp <- function (a){
  missing <- is.na(a)
  n_missing <- sum(missing)
  a_obs <- a[!missing]
  imputed <- a
  imputed[missing] <- sample(a_obs, n_missing)
  imputed
}
SIS$interest_imp <- random_imp(SIS$interest)
SIS$earnings_imp <- random_imp(SIS$earnings)

#' #### Simplest regression imputation
n_loop <- 10
for (s in 1:n_loop){
  fit <- stan_glm(earnings ~ interest_imp + male + over65 + white +
    immig + educ_r + workmos + workhrs_top + any_ssi + any_welfare +
    any_charity, data=SIS, refresh = 0)
  SIS_predictors <- SIS[,c("male","over65","white","immig","educ_r","workmos",
                           "workhrs_top","any_ssi","any_welfare","any_charity",
                           "interest_imp", "earnings_imp")]
  pred1 <- posterior_predict(fit, newdata = SIS_predictors, draws = 1)
  SIS$earnings_imp <- impute(SIS$earnings, pred1)
  
  fit <- stan_glm(interest ~ earnings_imp + male + over65 + white +
    immig + educ_r + workmos + workhrs_top + any_ssi + any_welfare +
    any_charity, data=SIS, refresh = 0)
  SIS_predictors <- SIS[,c("male","over65","white","immig","educ_r","workmos",
                           "workhrs_top","any_ssi","any_welfare","any_charity",
                           "interest_imp", "earnings_imp")]
  pred2 <- posterior_predict(fit, newdata = SIS_predictors, draws = 1)
  SIS$interest_imp <- impute(SIS$interest, pred2)
}
