################################################################################
###
### Replication of Fordham 2008, "Power or Plenty?", replacing CINC scores with
### DOE scores
###
### Replicating Table 2, third column (alliance onset with full set of controls)
###
################################################################################

library("caret")
library("dplyr")
library("foreign")

raw_fordham_2008 <- read.dta("fordham-2008.dta")
doe_dyad <- read.csv("../R/results-predict-dyad.csv")

## Rename spline variables generated by Stata
##
## R dislikes variable names starting with underscores
data_fordham_2008 <- raw_fordham_2008
names(data_fordham_2008) <- gsub("^\\_",
                                 "T.",
                                 names(data_fordham_2008))

## Convert response to factor and remove unused cases
data_fordham_2008 <- data_fordham_2008 %>%
    mutate(atopdo = factor(
               atopdo,
               levels = 0:1,
               labels = c("No", "Yes")
           )) %>%
    filter(ccode < 1000)

## To prevent spurious missingness in DOE scores, recode Germany 1992-2001 as
## Germany (255) instead of West Germany (260)
data_fordham_2008 <- within(data_fordham_2008,
                            ccode[ccode == 260 & year >= 1992] <- 255)

## Merge in DOE scores
##
## Using undirected form since CINC is used more as a proxy for raw power than
## as expectations about a specific conflict
data_fordham_2008 <- left_join(data_fordham_2008,
                               doe_dyad %>% filter(ccode_a == 2),
                               by = c(ccode = "ccode_b",
                                      year = "year"))
stopifnot(with(data_fordham_2008,
               sum(is.na(VictoryA) & !is.na(lncap_2)) == 0))

## Reproduce original model and cross-validate
set.seed(608)
f_fordham_2008 <-
    atopdo ~ lnexports1 + lndistance + lntotmids10_1 + lntotmids10_2 +
        lndyadmid10 + lncap_1 + lncap_2 + polity22 + coldwar + noallyrs +
        T.prefail + T.spline1 + T.spline2 + T.spline3
cr_fordham_2008 <- train(
    form = f_fordham_2008,
    data = data_fordham_2008,
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
    ),
    family = binomial(link = "probit")
)

## Don't save cross-validation indices (takes tons of space with large N)
cr_fordham_2008$control$index <- NULL
cr_fordham_2008$control$indexOut <- NULL

prettyNum(coef(cr_fordham_2008$finalModel))

## Replicate, replacing CINC scores with DOE scores
set.seed(806)
doe_fordham_2008 <- train(
    form = update(f_fordham_2008,
                  . ~ . - lncap_1 - lncap_2 + log(VictoryA) + log(VictoryB)),
    data = data_fordham_2008,
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
    ),
    family = binomial(link = "probit")
)

## Don't save cross-validation indices (takes tons of space with large N)
doe_fordham_2008$control$index <- NULL
doe_fordham_2008$control$indexOut <- NULL

prettyNum(coef(doe_fordham_2008$finalModel))

save(data_fordham_2008,
     cr_fordham_2008,
     doe_fordham_2008,
     file = "results-fordham-2008.rda")
