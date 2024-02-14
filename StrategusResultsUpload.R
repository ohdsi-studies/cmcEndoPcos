# Code for uploading results to a (Postgres) database
# If you want to use bulk uploading, activate these settings
# and provide the proper path to the PostgreSQL bin folder
#Sys.setenv("DATABASE_CONNECTOR_BULK_UPLOAD" = TRUE)
#Sys.setenv("POSTGRES_PATH" = "D:/Program Files/PostgreSQL/13/bin")

library(dplyr)
source("LoadConfiguration.R")

# Setup logging ----------------------------------------------------------------
ParallelLogger::clearLoggers()
ParallelLogger::addDefaultFileLogger(
  fileName = file.path(config$rootFolder, "upload-log.txt"),
  name = "RESULTS_FILE_LOGGER"
)
ParallelLogger::addDefaultErrorReportLogger(
  fileName = file.path(config$rootFolder, 'upload-errorReport.txt'),
  name = "RESULTS_ERROR_LOGGER"
)

# Connect to the database ------------------------------------------------------
connection <- DatabaseConnector::connect(connectionDetails = resultsDatabaseConnectionDetails)

# Upload results -----------------
isModuleComplete <- function(moduleFolder) {
  doneFileFound <- (length(list.files(path = moduleFolder, pattern = "done")) > 0)
  isDatabaseMetaDataFolder <- basename(moduleFolder) == "DatabaseMetaData"
  return(doneFileFound || isDatabaseMetaDataFolder)
}
for (i in seq_along(databases)) {
  database <- databases[[i]]
  message("Loading results for: ", database$databaseId, " in ", database$strategusResultsFolder)
  moduleFolders <- list.dirs(path = database$strategusResultsFolder, recursive = FALSE)
  for (moduleFolder in moduleFolders) {
    moduleName <- basename(moduleFolder)
    if (!isModuleComplete(moduleFolder)) {
      warning("Module ", moduleName, " did not complete. Skipping upload")
    } else {
      if (startsWith(moduleName, "PatientLevelPrediction")) {
        dbSchemaSettings <- PatientLevelPrediction::createDatabaseSchemaSettings(
          resultSchema = config$resultsDatabaseSchema,
          tablePrefix = "plp",
          targetDialect = DatabaseConnector::dbms(connection)
        )
        message("Loading PLP results for: ", database$databaseId, " in ", database$strategusResultsFolder)
        modulePath <- list.files(
          path = database$strategusResultsFolder, 
          pattern = "PatientLevelPredictionModule",
          full.names = TRUE,
          include.dirs = TRUE
        )
        performanceFile <- file.path(modulePath, "performances.csv")
        if (!file.exists(performanceFile)) {
          warning("PatientLevelPrediction module in ",modulePath, " did not complete. Skipping upload")
        } else {
          PatientLevelPrediction::insertCsvToDatabase(
            csvFolder = modulePath,
            connectionDetails = resultsDatabaseConnectionDetails,
            databaseSchemaSettings = dbSchemaSettings,
            modelSaveLocation = file.path(config$rootFolder, "PlPModels"),
            csvTableAppend = ""
          )
        }        
      } else {
        message("- Uploading results for module ", moduleName)
        rdmsFile <- file.path(moduleFolder, "resultsDataModelSpecification.csv")
        if (!file.exists(rdmsFile)) {
          stop("resultsDataModelSpecification.csv not found in ", resumoduleFolderltsFolder)
        } else {
          specification <- CohortGenerator::readCsv(file = rdmsFile)
          runCheckAndFixCommands = grepl("CohortDiagnostics", moduleName)
          ResultModelManager::uploadResults(
            connection = connection,
            schema = config$resultsDatabaseSchema,
            resultsFolder = moduleFolder,
            purgeSiteDataBeforeUploading = TRUE,
            databaseIdentifierFile = file.path(
              database$strategusResultsFolder,
              "DatabaseMetaData/database_meta_data.csv"
            ),
            runCheckAndFixCommands = runCheckAndFixCommands,
            specifications = specification
          )
        }
      }
    }
  }
}

# Grant read only permissions to all tables ------------------------------------
configureResultsSchema(
  connection = connection
)

# Disconnect from the database -------------------------------------------------
DatabaseConnector::disconnect(connection)

# Unregister loggers -----------------------------------------------------------
ParallelLogger::unregisterLogger("RESULTS_FILE_LOGGER")
ParallelLogger::unregisterLogger("RESULTS_ERROR_LOGGER")