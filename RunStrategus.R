# Run Strategus on the databases configured in config.yml
source("LoadConfiguration.R")

# Add a check to make sure that INSTANTIATED_MODULES_FOLDER is set
if (Sys.getenv("INSTANTIATED_MODULES_FOLDER") == "") {
  stop("Please set the INSTANTIATED_MODULES_FOLDER location in your .Rprofile so that Strategus has a known location to store the module files. To do this:
       - Call the function `usethis::edit_r_environ()` to open your .Renviron file
       - Add a line to the .Renviron file: INSTANTIATED_MODULES_FOLDER = 'C:/your/path/to/modules'
       - Close the .Renviron file
       - Restart your R session\n
Once you have completed the steps above, please try running this script again.")
}

# Code for running Strategus
analysisSpecifications <- ParallelLogger::loadSettingsFromJson(file.path(config$rootFolder, config$studySpecificationFileName))

for (i in seq_along(databases)) {
  databaseId <- databases[[i]]$databaseId
  connectionString <- keyring::key_get(paste0(config$keyringConnectionStringPrefix, databaseId), keyring = config$keyringName)
  connectionDetails <- DatabaseConnector::createConnectionDetails(
    dbms = "redshift",
    connectionString = connectionString,
    user = keyring::key_get("redShiftUserName", keyring = config$keyringName),
    password = keyring::key_get("redShiftPassword", keyring = config$keyringName)
  )
  #connectionDetails <- databases[[i]]$connectionDetails
  class(connectionDetails) <- c("connectionDetails", class(connectionDetails))
  Strategus::storeConnectionDetails(
    connectionDetails = connectionDetails,
    connectionDetailsReference = sprintf("cdRef_%s", databases[[i]]$databaseId),
    keyringName = config$keyringName
  )
}

# Create and save execution settings ----------------------------------------------------
for (i in seq_along(databases)) {
  executionSettings <- Strategus::createCdmExecutionSettings(
    connectionDetailsReference = sprintf("cdRef_%s", databases[[i]]$databaseId),
    workDatabaseSchema = databases[[i]]$cohortDatabaseSchema,
    cdmDatabaseSchema = databases[[i]]$cdmDatabaseSchema,
    cohortTableNames = CohortGenerator::getCohortTableNames(databases[[i]]$cohortTable),
    workFolder = databases[[i]]$strategusWorkFolder,
    resultsFolder = databases[[i]]$strategusResultsFolder,
    minCellCount = 5
  )
  
  # Save the execution settings in the results folder
  if (!dir.exists(databases[[i]]$databaseResultsRootFolder)) {
    dir.create(databases[[i]]$databaseResultsRootFolder, recursive = TRUE)
  }
  ParallelLogger::saveSettingsToJson(executionSettings, fileName = file.path(databases[[i]]$databaseResultsRootFolder, "executionSettings.json"))
  
  # Execute the study on the database
  Strategus::execute(
    analysisSpecifications = analysisSpecifications,
    executionSettings = executionSettings,
    executionScriptFolder = databases[[i]]$strategusExecutionFolder,
    keyringName = config$keyringName,
    restart = dir.exists(databases[[i]]$strategusExecutionFolder)
  )
}