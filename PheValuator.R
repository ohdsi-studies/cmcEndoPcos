# Code for running PheValuator, including generating the xSpec and xSens cohorts
# Assumes the cohort set has been downloaded and generated on the databases 
# (i.e., that Cohorts.R has been executed).

########################################################
# Load the configuration - DO NOT MODIFY ---------------
########################################################
# Load the study configuration
source("LoadConfiguration.R")

if (!dir.exists(file.path(config$rootFolder, "cohorts"))) {
  stop(paste0("Could not find the cohort folder. Did you run Cohorts.R yet to generate the cohorts?"))
}

cohortDefinitionSet <- CohortGenerator::getCohortDefinitionSet(
  settingsFileName = file.path(config$rootFolder, "cohorts/inst/Cohorts.csv"),
  jsonFolder = file.path(config$rootFolder, "cohorts/inst/cohorts"),
  sqlFolder = file.path(config$rootFolder, "cohorts/inst/sql/sql_server"),
  subsetJsonFolder = file.path(config$rootFolder, "cohorts/inst/cohort_subset_definitions")  
)
########################################################
# Above the line - MODIFY ------------------------------
########################################################

pheValuatorSettings <- list(
  list(
    phenotype = "Hypertension", # Pick a short name that is also friendly to save to the file system. Avoid special characters!
    cohortsToEvaluate = list(
      phenotypeCohortId = c(9900, 13826),
      washoutPeriod = c(0, 0), # This should match the prior observation requirements of the cohort to evaluate
      xSpecCohortId = 12863,
      daysFromxSpec = 14,
      excludedCovariateConceptIds = c(195213,314054,319826,321119,4118795,46271022),
      xSensCohortId = 12864,
      prevalenceCohortId = 12864, # You should have prevalence cohort which may be used as the xSens cohort
      covariateSettingsType = "chronic"
    )    
  ),
 list(
   phenotype = "MI", # Pick a short name that is also friendly to save to the file system. Avoid special characters!
   cohortsToEvaluate = list(
     phenotypeCohortId = c(2072),
     washoutPeriod = c(0), # This should match the prior observation requirements of the cohort to evaluate
     xSpecCohortId = 11081,
     daysFromxSpec = 1,
     excludedCovariateConceptIds = c(78786,253796,314383,317585,320739,440417,442077,4142905,40479589,314666),
     xSensCohortId = 4338,  
     prevalenceCohortId = 4338, # You should have prevalence cohort which may be used as the xSens cohort
     covariateSettingsType = "acute"
   )
 )
)

# Probably don't change below this line ----------------------------------------

# TODO: Should users change this and simply note the "type" of settings
# to use in the pheValuatorSettings object above?
chronicCovariateSettingsDefault <- list(
  addDescendantsToExclude = TRUE,
  startDayWindow1 = 0,
  endDayWindow1 = 30,
  startDayWindow2 = 31,
  endDayWindow2 = 60,
  startDayWindow3 = 61,
  endDayWindow3 = 365  
)

acuteCovariateSettingsDefault <- list(
  addDescendantsToExclude = TRUE,
  startDayWindow1 = 0,
  endDayWindow1 = 10,
  startDayWindow2 = 11,
  endDayWindow2 = 20,
  startDayWindow3 = 21,
  endDayWindow3 = 30
)

########################################################
# Below the line - DO NOT MODIFY -----------------------
########################################################

# TODO: validate the pheValuatorSettings to check things like
# 1. The settings have length > 1
# 2. There are unique combos of phenotypeCohortId to evaluate - there
#    should not be duplication in this list.
# 3. The length of the phenotypeCohortId vector must equal
#    the length of the washoutPeriod

# Run PheValuator --------------------------------------------------------------

# TODO: revise inner loop to reflect the change from a list of lists
# to make washoutPeriod, phenotypeCohortId as vectors. 
# Each vector entry should equal a new analysis with the same
# settings

for (i in seq_along(pheValuatorSettings)) {
  analysisList <- list()
  curPheValuatorSettings <- pheValuatorSettings[[i]]
  message("  -- ", curPheValuatorSettings$phenotype)
  for (j in seq_along(curPheValuatorSettings$cohortsToEvaluate$phenotypeCohortId)) {
    curCohortToEvaluateSettings <- curPheValuatorSettings$cohortsToEvaluate
    defaultCovariateSettingsToUse <- switch(
      EXPR = tolower(curCohortToEvaluateSettings$covariateSettingsType),
      "acute" = acuteCovariateSettingsDefault,
      "chronic" = chronicCovariateSettingsDefault
    )
    if (is.null(defaultCovariateSettingsToUse)) {
      stop(paste0("Default settings for ", curCohortToEvaluateSettings$covariateSettingsType, "not found. Please make sure it is set to 'acute' or 'chronic'"))
    }
    #print(paste0("DEBUG: ", curCohortToEvaluateSettings$covariateSettingsType, " = ", defaultCovariateSettingsToUse$endDayWindow1))
    covariateSettings <- PheValuator::createDefaultCovariateSettings(
      excludedCovariateConceptIds = curCohortToEvaluateSettings$excludedCovariateConceptIds,
      addDescendantsToExclude = defaultCovariateSettingsToUse$addDescendantsToExclude,
      startDayWindow1 = defaultCovariateSettingsToUse$startDayWindow1,
      endDayWindow1 = defaultCovariateSettingsToUse$endDayWindow1,
      startDayWindow2 = defaultCovariateSettingsToUse$startDayWindow2,
      endDayWindow2 = defaultCovariateSettingsToUse$endDayWindow2,
      startDayWindow3 = defaultCovariateSettingsToUse$startDayWindow3,
      endDayWindow3 = defaultCovariateSettingsToUse$endDayWindow3
    )
    
    createEvaluationCohortArgs <- PheValuator::createCreateEvaluationCohortArgs(
      xSpecCohortId = curCohortToEvaluateSettings$xSpecCohortId,
      daysFromxSpec = curCohortToEvaluateSettings$daysFromxSpec,
      xSensCohortId = curCohortToEvaluateSettings$xSensCohortId,
      prevalenceCohortId = curCohortToEvaluateSettings$prevalenceCohortId
    )
    testPhenotypeAlgorithmArgs <- PheValuator::createTestPhenotypeAlgorithmArgs(
      phenotypeCohortId = curCohortToEvaluateSettings$phenotypeCohortId[[j]],
      washoutPeriod = curCohortToEvaluateSettings$washoutPeriod[[j]]
    )
    analysisList[[j]] <- PheValuator::createPheValuatorAnalysis(
      analysisId = j,
      description = cohortDefinitionSet$cohortName[cohortDefinitionSet$cohortId == curCohortToEvaluateSettings$phenotypeCohortId[[j]]],
      createEvaluationCohortArgs = createEvaluationCohortArgs,
      testPhenotypeAlgorithmArgs = testPhenotypeAlgorithmArgs
    )
  }

  message("Running PheValator for ", curPheValuatorSettings$phenotype)
  for (j in seq_along(databases)) {
    database <- databases[[j]]
    message(sprintf(" -- Running PheValuator for %s", database$databaseId))
    if (!dir.exists(database$pheValuatorFolder)) {
      dir.create(database$pheValuatorFolder, recursive = T, showWarnings = F)
    }
    PheValuator::savePheValuatorAnalysisList(
      analysisList, 
      file.path(database$pheValuatorFolder, paste0(curPheValuatorSettings$phenotype, "_", config$pheValuator$analysisListFileName))
    )
    outputFolder <- file.path(database$pheValuatorFolder, curPheValuatorSettings$phenotype)
    connectionDetails <- do.call(
      DatabaseConnector::createConnectionDetails,
      database$connectionDetailsList
    )
    PheValuator::runPheValuatorAnalyses(
      phenotype = curPheValuatorSettings$phenotype,
      connectionDetails = connectionDetails,
      cdmDatabaseSchema = database$cdmDatabaseSchema,
      cohortDatabaseSchema = database$cohortDatabaseSchema,
      cohortTable = database$cohortTable,
      workDatabaseSchema = database$cohortDatabaseSchema,
      databaseId = database$databaseId,
      outputFolder = outputFolder,
      pheValuatorAnalysisList = analysisList
    )
    results <- PheValuator::summarizePheValuatorAnalyses(
      referenceTable = readRDS(file.path(outputFolder, "reference.rds")),
      outputFolder = outputFolder
    )
    readr::write_csv(results, file.path(outputFolder, "summary.csv"))
  }
}
