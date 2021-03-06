##############################################################################################################
#                     GENERAL DOWNSCALING                                                                    #
##############################################################################################################
##     downscale.predict.R Downscale climate data for a given statistical model.
##
##     Copyright (C) 2017 Santander Meteorology Group (http://www.meteo.unican.es)
##
##     This program is free software: you can redistribute it and/or modify
##     it under the terms of the GNU General Public License as published by
##     the Free Software Foundation, either version 3 of the License, or
##     (at your option) any later version.
## 
##     This program is distributed in the hope that it will be useful,
##     but WITHOUT ANY WARRANTY; without even the implied warranty of
##     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
##     GNU General Public License for more details.
## 
##     You should have received a copy of the GNU General Public License
##     along with this program.  If not, see <http://www.gnu.org/licenses/>.

#' @title Downscale climate data for a given statistical model.
#' @description Downscale data to local scales by statistical models previously obtained by \code{\link[downscaleR]{downscale.train}}.
#' @param newdata The grid data. It should be an object as returned by  \code{\link[downscaleR]{prepare_newdata}}.
#' @param model An object containing the statistical model as returned from  \code{\link[downscaleR]{downscale.train}}.
#' @return An object with the predictions.
#' @details The function can downscale in both global and local mode, though not simultaneously.
#' @author J. Bano-Medina
#' @export
#' @examples 
#' # Loading predictors
#' x <- makeMultiGrid(NCEP_Iberia_hus850, NCEP_Iberia_ta850)
#' x <- subsetGrid(x, years = 1985:1995)
#' # Loading predictands
#' y <- VALUE_Iberia_pr
#' y <- getTemporalIntersection(obs = y,prd = x, "obs" )
#' x <- getTemporalIntersection(obs = y,prd = x, "prd" )
#' ybin <- convert2bin(y, threshold = 1)
#' x <- localScaling(x, base = x, scale = TRUE)
#' # Prepare predictors and predictands
#' xyT     <- prepare_predictors(x = x, y = y)
#' xyT.bin <- prepare_predictors(x = x, y = ybin)
#' xyt     <- prepare_newdata(newdata = x, predictor = xyT)
#' xyt.bin <- prepare_newdata(newdata = x, predictor = xyT.bin)
#' # Downscaling PRECIPITATION
#' # ... via analogs ...
#' model <- downscale.train(xyT, method = "analogs", sel.fun = "mean", singlesite = FALSE)
#' pred <- downscale.predict(xyt, model)
#' # ... via a logistic regression (ocurrence of precipitation) and gaussian regression (amount of precipitation) ...
#' model.ocu <- downscale.train(xyT.bin, method = "GLM", family = binomial(link = "logit"))
#' model.reg <- downscale.train(xyT,     method = "GLM", family = "gaussian", filt = ">0")
#' pred.ocu <- downscale.predict(xyt.bin, model.ocu)
#' pred.reg <- downscale.predict(xyt    , model.reg)
#' # ... via a neural network ...
#' model.ocu <- downscale.train(xyT.bin, method = "NN", singlesite = FALSE, learningrate = 0.1, numepochs = 10, hidden = 5, output = 'linear')
#' model.reg <- downscale.train(xyT    , method = "NN", singlesite = FALSE, learningrate = 0.1, numepochs = 10, hidden = 5, output = 'linear')
#' pred.ocu <- downscale.predict(xyT.bin, model.ocu)
#' pred.reg <- downscale.predict(xyT    , model.reg)
#' # Downscaling PRECIPITATION - Local model with the closest 4 grid points.
#' xyT.local     <- prepare_predictors(x = x,y = y,local.predictors = list(neigh.vars = "shum@850",n.neighs = 4))
#' xyT.local.bin <- prepare_predictors(x = x,y = ybin,local.predictors = list(neigh.vars = "shum@850",n.neighs = 4))
#' xyt.local     <- prepare_newdata(newdata = x, predictor = xyT.local)
#' xyt.local.bin <- prepare_newdata(newdata = x, predictor = xyT.local.bin)
#' model.ocu <- downscale.train(xyT.local.bin, method = "GLM", fitting = 'MP')
#' model.reg <- downscale.train(xyT.local    , method = "GLM", fitting = 'MP')
#' pred.ocu <- downscale.predict(xyt.local.bin, model.ocu)
#' pred.reg <- downscale.predict(xyt.local    , model.reg)
#' # Downscaling PRECIPITATION - Principal Components (PCs) and gamma regression for the amount of precipitation
#' xyT.pc     <- prepare_predictors(x = x,y = y, PCA = list(which.combine = getVarNames(x),v.exp = 0.9))
#' xyT.pc.bin <- prepare_predictors(x = x,y = ybin, PCA = list(which.combine = getVarNames(x),v.exp = 0.9))
#' xyt.pc     <- prepare_newdata(newdata = x, predictor = xyT.pc)
#' xyt.pc.bin <- prepare_newdata(newdata = x, predictor = xyT.pc.bin)
#' model.ocu <- downscale.train(xyT.pc.bin, method = "GLM" , family = binomial(link = "logit"))
#' model.reg <- downscale.train(xyT.pc    , method = "GLM" , family = Gamma(link = "log"), filt = ">0")
#' pred.ocu <- downscale.predict(xyt.pc.bin, model.ocu)
#' pred.reg <- downscale.predict(xyt.pc    , model.reg)

downscale.predict <- function(newdata, model) {
  dimNames <- getDim(model$pred)
  pred <- model$pred
  pred$Dates <- newdata$Dates
  if (!isTRUE(model$conf$singlesite)) {
    if (!is.list(newdata$x.global)) {
      xx <- newdata$x.global}
    else {
      xx <- newdata$x.global$member_1}
    if (model$conf$method == "analogs") {model$conf$atomic_model$dates$test <- getRefDates(newdata)}
    pred$Data <- downs.predict(xx, model$conf$method, model$conf$atomic_model)}
  else {
    stations <- length(model$conf$atomic_model)
    if (!is.null(newdata$x.local)) {
      if (!is.list(newdata$x.local[[1]])) {n.obs <- nrow(as.matrix(newdata$x.local[[1]]))}
      else{n.obs <- nrow(as.matrix(newdata$x.local[[1]]$member_1))}}
    else {
      if (!is.list(newdata$x.global)) {n.obs <- nrow(as.matrix(newdata$x.global))} 
      else {n.obs <- nrow(as.matrix(newdata$x.global$member_1))}}
      pred$Data <- array(data = NA, dim = c(n.obs,stations))
      for (i in 1:stations) {
        if (!is.null(newdata$x.local)) {
          if (!is.list(newdata$x.local[[i]])) {
            xx = newdata$x.local[[i]]}
          else {
            xx = newdata$x.local[[i]]$member_1}}
        else {
          if (!is.list(newdata$x.global)) {
            xx <- newdata$x.global}
          else {
            xx <- newdata$x.global$member_1}}
      if (model$conf$method == "analogs") {model$conf$atomic_model[[i]]$dates$test <- getRefDates(newdata)}
      pred$Data[,i] <- downs.predict(xx, model$conf$method, model$conf$atomic_model[[i]])}}
  attr(pred$Data, "dimensions") <- dimNames
  return(pred)}

##############################################################################################################
#                     DOWNSCALING                                                                            #
##############################################################################################################
#' @title Switch to selected downscale method.
#' @description Internal function of \code{\link[downscaleR]{downscale.predict}} that switches to the corresponding method.
#' @param x The grid data. Class: matrix.
#' @param method The method of the given model.
#' @param atomic_model An object containing the statistical model of the selected method.
#' @return A matrix with the predictions.
#' @details This function is internal and should not be used by the user. The user should use \code{\link[downscaleR]{downscale.predict}}.
#' @author J. Bano-Medina
#' @export
downs.predict <- function(x, method, atomic_model){
  switch(method,
         analogs = pred <- analogs.test(x, atomic_model$dataset_x, atomic_model$dataset_y, atomic_model$dates, atomic_model$info),
         GLM     = pred <- glm.predict(x, atomic_model$weights, atomic_model$info),
         NN      = pred <- nn.predict(atomic_model, x)) 
  return(pred)}