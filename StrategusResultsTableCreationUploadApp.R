# WARNING: this script is Work In Progress (WIP)
# USE WITH CAUTION
#
# given a study result folder for a particular database 
# this script will: 
#   * create a unique database file per each script execution
#   * create the necessary tables for the results in a sqlite database
#   * load the database with the results data
#   * perform results introspection to determine modules to configure in app viewer
#   * launch the app viewer for your results
#

library(dplyr)
library(ShinyAppBuilder)

isModuleComplete <- function(moduleFolder) {
  doneFileFound <- (length(list.files(path = moduleFolder, pattern = "done")) > 0)
  isDatabaseMetaDataFolder <- basename(moduleFolder) == "DatabaseMetaData"
  return(doneFileFound || isDatabaseMetaDataFolder)
}

getInferredShinyAppConfig <- function(strategusResultsFolder) {
  moduleFolders <- list.dirs(path = strategusResultsFolder, recursive = FALSE)
  
  # discover module configuration
  useAppModulePatientLevelPrediction <- FALSE
  useAppModuleCohortDiagnostics <- FALSE
  useAppModuleCharacterization <- FALSE
  useAppModuleCohortGenerator <- FALSE
  useAppModuleCohortIncidence <- FALSE
  useAppModuleCohortMethod <- FALSE  
  
  for (moduleFolder in moduleFolders) {
    moduleName <- basename(moduleFolder)
    if (startsWith(moduleName,"PatientLevelPrediction")) {
      useAppModulePatientLevelPrediction <- TRUE
    }
    if (startsWith(moduleName,"Characterization")) {
      useAppModuleCharacterization <- TRUE
    }
    if (startsWith(moduleName,"CohortGenerator")) {
      useAppModuleCohortGenerator <- TRUE
    }
    if (startsWith(moduleName, "CohortIncidence")) {
      useAppModuleCohortIncidence <- TRUE
    }
  }
  
  # configure and launch shiny app
  config <- initializeModuleConfig() %>%
    addModuleConfig(createDefaultAboutConfig()) %>%
    addModuleConfig(createDefaultDatasourcesConfig())
  
  if (useAppModuleCohortGenerator) {
    config <- config %>%
      addModuleConfig(createDefaultCohortGeneratorConfig())
  }
  
  if (useAppModuleCharacterization) {
    config <- config %>%
      addModuleConfig(createDefaultCharacterizationConfig()) 
  }
  
  if (useAppModuleCohortDiagnostics) {
    config <- config %>%
      addModuleConfig(createDefaultCohortDiagnosticsConfig()) 
  }
  
  if (useAppModuleCohortMethod) {
    config <- config %>%
      addModuleConfig(createDefaultCohortMethodConfig()) 
  }
  
  if (useAppModulePatientLevelPrediction) {
    config <- config %>%
      addModuleConfig(createDefaultPredictionConfig())
  }
  
  return(config)
}

# create the sqlite database file and initialize the necessary tables
# limitation: if you prepare on a result folder for a database that doesn't have all modules
#   that other databases have then the proper tables would not be created
# to improve on this, prepare the database after inspecting all subfolders and collecting
#   boolean flags for which preparation steps should be employed such as the infer function
prepareSqliteDatabase <- function(strategusResultsFolder, resultsDatabaseSchema = "main") {
  releaseKey <- format(Sys.time(), "%Y%m%d_%H%M")
  databaseFileName <- file.path(strategusResultsFolder, paste0("results_", releaseKey, ".sqlite"))
  resultsDatabaseConnectionDetails <- DatabaseConnector::createConnectionDetails(
    dbms = "sqlite",
    server = databaseFileName
  )
  connection <- DatabaseConnector::connect(
    connectionDetails = resultsDatabaseConnectionDetails
  )
  moduleFolders <- list.dirs(path = strategusResultsFolder, recursive = FALSE)
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
        CohortDiagnostics::migrateDataModel(
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
  DatabaseConnector::disconnect(connection)
  message("created database file ", databaseFileName)
  return(resultsDatabaseConnectionDetails)
}

loadSqliteDatabase <- function(databaseId, strategusResultsFolder, resultsDatabaseConnectionDetails, resultsDatabaseSchema="main") {
  message("Loading results for: ", databaseId, " in ", strategusResultsFolder)
  moduleFolders <- list.dirs(path = strategusResultsFolder, recursive = FALSE)
  
  connection <- DatabaseConnector::connect(resultsDatabaseConnectionDetails)
  
  for (moduleFolder in moduleFolders) {
    moduleName <- basename(moduleFolder)
    if (!isModuleComplete(moduleFolder)) {
      warning("Module ", moduleName, " did not complete. Skipping upload")
    } else {
      if (startsWith(moduleName, "PatientLevelPrediction")) {
        dbSchemaSettings <- PatientLevelPrediction::createDatabaseSchemaSettings(
          resultSchema = resultsDatabaseSchema,
          tablePrefix = "plp",
          targetDialect = DatabaseConnector::dbms(connection)
        )
        message("Loading PLP results for: ", databaseId, " in ", strategusResultsFolder)
        modulePath <- list.files(
          path = strategusResultsFolder, 
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
            modelSaveLocation = file.path(moduleFolder, "PlPModels"),
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
            schema = resultsDatabaseSchema,
            resultsFolder = moduleFolder,
            purgeSiteDataBeforeUploading = TRUE,
            databaseIdentifierFile = file.path(
              strategusResultsFolder,
              "DatabaseMetaData/database_meta_data.csv"
            ),
            runCheckAndFixCommands = runCheckAndFixCommands,
            specifications = specification
          )
        }
      }
    }
  }
  DatabaseConnector::disconnect(connection)
}

# study specific code
strategusResultsFolder <- "D:/projects/CUStudyathon/results/Ccae/strategusResults"

appConfig <- getInferredShinyAppConfig(strategusResultsFolder)

resultsDatabaseConnectionDetails <- prepareSqliteDatabase(
  strategusResultsFolder = strategusResultsFolder
)

loadSqliteDatabase(
  databaseId = "ccae",
  strategusResultsFolder = strategusResultsFolder, 
  resultsDatabaseConnectionDetails
)

resultsConnection <- ResultModelManager::ConnectionHandler$new(resultsDatabaseConnectionDetails)

ShinyAppBuilder::viewShiny(
  config = appConfig, 
  connection = resultsConnection
)

