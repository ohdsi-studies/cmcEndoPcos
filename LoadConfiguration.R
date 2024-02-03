# Code for setting the connection details and schemas for the various databases,
# as well as some folders in the local file system.

# Get the study configuration from the config.yml ----------
config <- config::get(config = "studySettings")

if (config$studyName == "") {
  cli::cli_abort(c(
    "The config.yml file requires a value for the studyName which is currently set to '{config$studyName}'. Please set it to be a value such as 'epi_12345'"
  ))
}

# Ensure the keyring is unlocked -------------
Strategus:::unlockKeyring(keyringName = config$keyringName)

# Build the databases list --------------------
cdmSources <- names(config$cdm)[!names(config$cdm) %in% names(config)]
databases <- list()
# NOTE: Removing the connectionDetails construction in this loop
# since it assigns the last connectionDetails object to all 
# list entries
for (i in seq_along(cdmSources)) {
  databaseId <- cdmSources[i]
  connectionString <- keyring::key_get(paste0(config$keyringConnectionStringPrefix, databaseId), keyring = config$keyringName)
  connectionDetailsList <- list(
    dbms = "redshift",
    connectionString = connectionString,
    user = keyring::key_get("redShiftUserName", keyring = config$keyringName),
    password = keyring::key_get("redShiftPassword", keyring = config$keyringName)
  )  
  #print(paste0(connectionString, " ?= ", connectionDetails$connectionString()))
  databases[[length(databases) + 1]] <- list(
    databaseId = databaseId,
    connectionDetailsList = connectionDetailsList,
    cohortDatabaseSchema = keyring::key_get("redShiftScratchSchema", keyring = config$keyringName),
    cdmDatabaseSchema = config$cdm[[cdmSources[i]]]
  )
}

# Set cohort table and folders -------------------------------------------------
for (i in seq_along(databases)) {
  databaseId <- databases[[i]]$databaseId
  databases[[i]]$cohortTable <- sprintf("cohort_%s_%s", config$studyName, databaseId)
  databases[[i]]$databaseResultsRootFolder <- file.path(config$rootFolder, "results", databaseId)
  databases[[i]]$cohortDiagnosticsFolder = file.path(databases[[i]]$databaseResultsRootFolder, "cohortDiagnostics")
  databases[[i]]$pheValuatorFolder = file.path(databases[[i]]$databaseResultsRootFolder, ("pheValuator"))
  databases[[i]]$strategusResultsFolder = file.path(databases[[i]]$databaseResultsRootFolder, ("strategusResults"))
  # Set the Strategus internals folders - these will be explicitly ignored by git so that they are not
  # automatically included in the study repo due to size considerations
  databases[[i]]$strategusInternalsRootFolder <- file.path(config$rootFolder, "strategusInternals", databaseId)
  databases[[i]]$strategusWorkFolder <- file.path(databases[[i]]$strategusInternalsRootFolder, ("strategusWork"))
  databases[[i]]$strategusExecutionFolder = file.path(databases[[i]]$strategusInternalsRootFolder, ("strategusExecution"))
}

# Results database -------------------------------------------------------------
resultsDatabaseConnectionDetails <- DatabaseConnector::createConnectionDetails(
  dbms = "postgresql",
  connectionString = keyring::key_get("resultsConnectionString", keyring = config$keyringName),
  user = keyring::key_get("resultsAdmin", keyring = config$keyringName),
  password = keyring::key_get("resultsAdminPassword", keyring = config$keyringName)
)

# This helper function is used to set permissions for the read-only account
# to all tables in the results schema and to run the ANALYZE command for all 
# tables in the results schema
configureResultsSchema <- function(connection = NULL) {
  if (is.null(connection)) {
    connection <- DatabaseConnector::connect(
      connectionDetails = resultsDatabaseConnectionDetails
    )
    on.exit(DatabaseConnector::disconnect(connection))
  }
  
  # Grant read only permissions to all tables
  sql <- "GRANT USAGE ON SCHEMA @schema TO @results_user;
  GRANT SELECT ON ALL TABLES IN SCHEMA @schema TO @results_user; 
  GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA @schema TO @results_user;"
  
  message("Setting permissions for results schema")
  sql <- SqlRender::render(
    sql = sql, 
    schema = config$resultsDatabaseSchema,
    results_user = keyring::key_get("resultsReadOnlyUser", keyring = config$keyringName)
  )
  DatabaseConnector::executeSql(
    connection = connection, 
    sql = sql,
    progressBar = FALSE,
    reportOverallTime = FALSE
  )
  
  # Analyze all tables in the results schema
  message("Analyzing all tables in results schema")
  sql <- "ANALYZE @schema.@table_name;"
  tableList <- DatabaseConnector::getTableNames(
    connection = connection,
    databaseSchema = config$resultsDatabaseSchema
  )
  for (i in 1:length(tableList)) {
    DatabaseConnector::renderTranslateExecuteSql(
      connection = connection,
      sql = sql,
      schema = config$resultsDatabaseSchema,
      table_name = tableList[i],
      progressBar = FALSE,
      reportOverallTime = FALSE
    )
  }
}

# Data Profile database ---------------
## Create the connection details for the database where the dbProfile results are held
dbProfileConnectionDetails <- DatabaseConnector::createConnectionDetails(
  dbms = "postgresql",
  connectionString = keyring::key_get("dpResultsServer", keyring = config$keyringName),
  user = keyring::key_get("dpReadOnlyUser", keyring = config$keyringName),
  password = keyring::key_get("dpReadOnlyPassword", keyring = config$keyringName)
)
