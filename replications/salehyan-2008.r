################################################################################
###
### Replication of Salehyan 2008, "No Shelter Here," 
### replacing CINC ratio with DOE scores
###
### Replicating Table 1, Column 1
###
################################################################################

library("caret")
library("dplyr")
library("foreign")
library("MASS")

data_salehyan_2008 <- read.dta("salehyan-2008.dta")
doe_dyad <- read.csv("../R/results-predict-dyad.csv")

## add the correct dependent variable
data_salehyan_2008$DV <- ifelse(data_salehyan_2008$cwhostd >= 4, 1, 0)

## replication formula
f_salehyan_2008 <- 
  DV ~ extbase + intriv + lcaprat + defpact + politylo + peaceyears + 
  s1 + s2 + s3

## check results
reported_model <- glm(formula = f_salehyan_2008,
                      data = data_salehyan_2008,
                      family = binomial(link = "logit"))
summary(reported_model)
                           ## replication is exact

## switch DV to factor for caret
data_salehyan_2008$DV <- factor(data_salehyan_2008$DV,
                                levels = 0:1,
                                labels = c("No", "Yes"))

## run the reported model with cross validation
set.seed(90210)
cr_salehyan_2008 <- train(
  f_salehyan_2008,
  data = data_salehyan_2008,
  method = "glm",
  metric = "logLoss",
  trControl = trainControl(
    method = "repeatedcv",
    number = 10,
    repeats = 100,
    returnData = FALSE,
    summaryFunction = mnLogLoss,
    classProbs = TRUE,
    trim = TRUE
  )
)

## Don't save cross-validation indices (takes tons of space with large N)
cr_salehyan_2008$control$index <- NULL
cr_salehyan_2008$control$indexOut <- NULL

prettyNum(coef(cr_salehyan_2008$finalModel))

## merge in the DOE scores and compute pairwise max and min (since A and B are
## exchangeable in undirected data)
data_salehyan_2008 <- left_join(data_salehyan_2008,
                                doe_dyad,
                                by = c(ccode1 = "ccode_a",
                                       ccode2 = "ccode_b",
                                       year = "year")) %>%
    mutate(VictoryMax = pmax(VictoryA, VictoryB),
           VictoryMin = pmin(VictoryA, VictoryB))

## DOE scores in every row:
length(which(is.na(data_salehyan_2008$VictoryA)))

## he logs, so we log
data_salehyan_2008$logVictoryMax <- log(data_salehyan_2008$VictoryMax)
data_salehyan_2008$logVictoryMin <- log(data_salehyan_2008$VictoryMin)

set.seed(8032)
doeForm <- update(f_salehyan_2008,
                   . ~ . - lcaprat + logVictoryMax + logVictoryMin)
doe_salehyan_2008 <-  train(
  doeForm,
  data = data_salehyan_2008,
  method = "glm",
  metric = "logLoss",
  trControl = trainControl(
    method = "repeatedcv",
    number = 10,
    repeats = 100,
    returnData = FALSE,
    summaryFunction = mnLogLoss,
    classProbs = TRUE,
    trim = TRUE
  )
)

## Don't save cross-validation indices (takes tons of space with large N)
doe_salehyan_2008$control$index <- NULL
doe_salehyan_2008$control$indexOut <- NULL

prettyNum(coef(doe_salehyan_2008$finalModel))

save(data_salehyan_2008,
     cr_salehyan_2008,
     doe_salehyan_2008,
     file = "results-salehyan-2008.rda")