# manually enter the results schema on the OHDSI PG server that you would like to create your tables in
resultsDatabaseSchema <- "<manually enter resultsDatabaseSchema name e.g. cmcPcosPred>"


# Create and store connection details for the results database -------------------------------------------------------------

resultsDatabaseConnectionDetails <- DatabaseConnector::createConnectionDetails(
  dbms = "sqlite",
  connectionString = ""
  # user = ,
  # password =
)

# Code for creating the result schema and tables in a (Postgres) database
library(dplyr)

rootFolder <- getwd()

# Setup logging ----------------------------------------------------------------
ParallelLogger::clearLoggers()
ParallelLogger::addDefaultFileLogger(
  fileName = file.path(rootFolder, "results-schema-setup-log.txt"),
  name = "RESULTS_SCHEMA_SETUP_FILE_LOGGER"
)
ParallelLogger::addDefaultErrorReportLogger(
  fileName = file.path(rootFolder, 'results-schema-setup-errorReport.txt'),
  name = "RESULTS_SCHEMA_SETUP_ERROR_LOGGER"
)

# Connect to the database ------------------------------------------------------
connection <- DatabaseConnector::connect(connectionDetails = resultsDatabaseConnectionDetails)

# Create the schema ------------------------------------------------------------
tryCatch(
  expr = {
    sql <- "CREATE SCHEMA @schema;"
    sql <- SqlRender::render(sql = sql, schema = resultsDatabaseSchema)
    DatabaseConnector::executeSql(connection = connection, sql = sql)
  }, 
  error = function(e) {
    errorMsg <- paste0(
      e,
      "\n----------------------------------------------\n",
      "A schema with results already exists!\n",
      "----------------------------------------------\n",
      "Do you want to drop this schema and recreate all tables?\nNOTE: This will remove all previous results that have been uploaded.\n"
    )
    message(errorMsg)
    switch(
      menu(
        choices = c(
          no = "Stop this process and preserve the results schema and all tables.",
          yes = "Recreate results schema and tables which will remove all results."
        ),
        title = "How would you like to proceed?"
      ) + 1,
      cat("Nothing done\n"),
      no = {
        cli::cli_inform("Stopping this script.")
        DatabaseConnector::disconnect(connection = connection)
      }
      ,
      yes = {
        sql <- "DROP SCHEMA IF EXISTS @schema CASCADE; CREATE SCHEMA @schema;"
        sql <- SqlRender::render(sql = sql, schema = resultsDatabaseSchema)
        DatabaseConnector::executeSql(connection = connection, sql = sql)
      }
    )
  }  
)

# Create the tables ------------------------
if (length(databases) <= 0) {
  stop("No databases found for upload; there must be at least 1 database specified in Databases.R")
}
database <- databases[[1]]
moduleFolders <- list.dirs(path = database$strategusResultsFolder, recursive = FALSE)
isModuleComplete <- function(moduleFolder) {
  doneFileFound <- (length(list.files(path = moduleFolder, pattern = "done")) > 0)
  isDatabaseMetaDataFolder <- basename(moduleFolder) == "DatabaseMetaData"
  return(doneFileFound || isDatabaseMetaDataFolder)
}
message("Creating result tables based on definitions found in ", database$strategusResultsFolder)
for (moduleFolder in moduleFolders) {
  moduleName <- basename(moduleFolder)
  if (!isModuleComplete(moduleFolder)) {
    warning("Module ", moduleName, " did not complete. Skipping table creation")
  } else {
    if (startsWith(moduleName, "PatientLevelPrediction")) {
      message("- Creating PatientLevelPrediction tables")
      dbSchemaSettings <- PatientLevelPrediction::createDatabaseSchemaSettings(
        resultSchema = resultsDatabaseSchema,
        tablePrefix = "plp",
        targetDialect = DatabaseConnector::dbms(connection)
      )
      PatientLevelPrediction::createPlpResultTables(
        connectionDetails = resultsDatabaseConnectionDetails,
        targetDialect = dbSchemaSettings$targetDialect,
        resultSchema = dbSchemaSettings$resultSchema,
        deleteTables = TRUE,
        createTables = TRUE,
        tablePrefix = dbSchemaSettings$tablePrefix
      )
    } else if (startsWith(moduleName, "CohortDiagnostics")) {
      message("- Creating CohortDiagnostics tables")
      CohortDiagnostics::createResultsDataModel(
        connectionDetails = resultsDatabaseConnectionDetails,
        databaseSchema = resultsDatabaseSchema,
        tablePrefix = "cd_"
      )
    } else {
      message("- Creating results for module ", moduleName)
      rdmsFile <- file.path(moduleFolder, "resultsDataModelSpecification.csv")
      if (!file.exists(rdmsFile)) {
        stop("resultsDataModelSpecification.csv not found in ", resumoduleFolderltsFolder)
      } else {
        specification <- CohortGenerator::readCsv(file = rdmsFile)
        sql <- ResultModelManager::generateSqlSchema(csvFilepath = rdmsFile)
        sql <- SqlRender::render(
          sql = sql,
          database_schema = resultsDatabaseSchema
        )
        DatabaseConnector::executeSql(connection = connection, sql = sql)
      }
    }
  }
}

# # Future Approach (Under Construction)
# analysisSpecifications <- ParallelLogger::loadSettingsFromJson(file.path(config$rootFolder, config$studySpecificationFileName))
# 
# # Store the results connection for upload
# resultsConnectionReference <- "result-store"
# Strategus::storeConnectionDetails(
#   resultsDatabaseConnectionDetails,
#   resultsConnectionReference,
#   keyringName = config$keyringName
# )
# 
# # Create the results schema so it is ready for uploading results
# Strategus::createResultDataModels(
#   analysisSpecifications = analysisSpecifications,
#   executionSettings = Strategus::createResultsExecutionSettings(
#     resultsConnectionDetailsReference = resultsConnectionReference,
#     resultsDatabaseSchema = config$resultsDatabaseSchema,
#     workFolder = file.path(config$rootFolder, "strategusInternals", "resultsDataModel", "strategusWork"),
#     resultsFolder = file.path(config$rootFolder, "strategusInternals", "resultsDataModel", "results"),
#     minCellCount = 0
#   )
# )

# Disconnect from the database -------------------------------------------------
DatabaseConnector::disconnect(connection)

# Unregister loggers -----------------------------------------------------------
ParallelLogger::unregisterLogger("RESULTS_SCHEMA_SETUP_FILE_LOGGER")
ParallelLogger::unregisterLogger("RESULTS_SCHEMA_SETUP_ERROR_LOGGER")