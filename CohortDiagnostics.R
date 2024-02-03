# Code for running cohort diagnostics. Assumes the cohort set has been downloaded
# and generated on the databases (i.e., that Cohorts.R has been executed).
source("LoadConfiguration.R")

# Run cohort diagnostics per database ------------------------------------------
if (!dir.exists(file.path(config$rootFolder, "cohorts"))) {
  stop(paste0("Could not find the cohort folder. Did you run Cohorts.R yet to generate the cohorts?"))
}

cohortDefinitionSet <- CohortGenerator::getCohortDefinitionSet(
  settingsFileName = file.path(config$rootFolder, "cohorts/inst/Cohorts.csv"),
  jsonFolder = file.path(config$rootFolder, "cohorts/inst/cohorts"),
  sqlFolder = file.path(config$rootFolder, "cohorts/inst/sql/sql_server"),
  subsetJsonFolder = file.path(config$rootFolder, "cohorts/inst/cohort_subset_definitions")  
)

for (i in seq_along(databases)) {
  database <- databases[[i]]
  message(sprintf("Creating cohort diagnostics for %s", database$databaseId))
  CohortDiagnostics::executeDiagnostics(
    exportFolder = database$cohortDiagnosticsFolder,
    databaseId = database$databaseId,
    connectionDetails = do.call(DatabaseConnector::createConnectionDetails, database$connectionDetailsList),
    cdmDatabaseSchema = database$cdmDatabaseSchema,
    cohortDatabaseSchema = database$cohortDatabaseSchema,
    cohortTableNames = CohortGenerator::getCohortTableNames(cohortTable = database$cohortTable),
    cohortDefinitionSet = cohortDefinitionSet,
    cohortIds = config$cohortDiagnostics$cohortIds,
    incremental = TRUE,
    incrementalFolder = database$cohortDiagnosticsFolder
  )
}

# Merge cohort diagnostics across databases ------------------------------------
source("LoadConfiguration.R")

tempFolder <- tempfile()
dir.create(tempFolder)

for (i in seq_along(databases)) {
  database <- databases[[i]]
  file.copy(
    from = file.path(database$cohortDiagnosticsFolder, sprintf("Results_%s.zip", database$databaseId)),
    to = tempFolder
  )  
}
CohortDiagnostics::createMergedResultsFile(
  dataFolder = tempFolder,
  sqliteDbPath = file.path(config$rootFolder, "CohortDiagnostics.sqlite"),
  overwrite = TRUE
)
unlink(tempFolder, recursive = TRUE)
CohortDiagnostics::createDiagnosticsExplorerZip(
  outputZipfile = file.path(config$rootFolder, "DiagnosticsExplorer.zip"),
  sqliteDbPath = file.path(config$rootFolder, "CohortDiagnostics.sqlite"),
  overwrite = TRUE
)

# Launch Shiny app -------------------------------------------------------------
CohortDiagnostics::launchDiagnosticsExplorer(
  sqliteDbPath = file.path(config$rootFolder, "CohortDiagnostics.sqlite")
)
