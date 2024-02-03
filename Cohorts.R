# Code to extract relevant cohorts, save them as a set, and generate them
source("LoadConfiguration.R")

# Extract from WebApi and save to file -----------------------------------------
cohortIds <- config$cohorts$cohortIds

ROhdsiWebApi::authorizeWebApi(
  baseUrl = keyring::key_get("webApiUrl", keyring = config$keyringName),
  authMethod = "windows")
cohortDefinitionSet <- ROhdsiWebApi::exportCohortDefinitionSet(
  baseUrl = keyring::key_get("webApiUrl", keyring = config$keyringName),
  cohortIds = cohortIds,
  generateStats = TRUE
)
if (!dir.exists(file.path(config$rootFolder, "cohorts"))) {
  dir.create(
    path = file.path(config$rootFolder, "cohorts"),
    showWarnings = FALSE,
    recursive = TRUE
  )
}

CohortGenerator::saveCohortDefinitionSet(
  cohortDefinitionSet = cohortDefinitionSet,
  settingsFileName = file.path(config$rootFolder, "cohorts/inst/Cohorts.csv"),
  jsonFolder = file.path(config$rootFolder, "cohorts/inst/cohorts"),
  sqlFolder = file.path(config$rootFolder, "cohorts/inst/sql/sql_server"),
  subsetJsonFolder = file.path(config$rootFolder, "cohorts/inst/cohort_subset_definitions")
)

# Generate Cohorts--------------------------------------------------------------
cohortDefinitionSet <- CohortGenerator::getCohortDefinitionSet(
  settingsFileName = file.path(config$rootFolder, "cohorts/inst/Cohorts.csv"),
  jsonFolder = file.path(config$rootFolder, "cohorts/inst/cohorts"),
  sqlFolder = file.path(config$rootFolder, "cohorts/inst/sql/sql_server"),
  subsetJsonFolder = file.path(config$rootFolder, "cohorts/inst/cohort_subset_definitions")  
)

for (i in seq_along(databases)) {
  database <- databases[[i]]
  message(sprintf("Creating cohorts for %s", database$databaseId))
  connection <- do.call(what = DatabaseConnector::connect,
                        args = database$connectionDetailsList)
  cohortTableNames <- CohortGenerator::getCohortTableNames(database$cohortTable)
  CohortGenerator::createCohortTables(
    connection = connection,
    cohortDatabaseSchema = database$cohortDatabaseSchema,
    cohortTableNames = cohortTableNames, 
    incremental = T
  )
  CohortGenerator::generateCohortSet(
    connection = connection,
    cdmDatabaseSchema = database$cdmDatabaseSchema,
    cohortDatabaseSchema = database$cohortDatabaseSchema,
    cohortTableNames = cohortTableNames,
    cohortDefinitionSet = cohortDefinitionSet,
    incremental = TRUE,
    incrementalFolder = file.path(config$rootFolder, "cohorts", database$databaseId)
  )
  DatabaseConnector::disconnect(connection)
}