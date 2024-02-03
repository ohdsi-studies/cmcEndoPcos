# Add a check to make sure that INSTANTIATED_MODULES_FOLDER is set
if (Sys.getenv("INSTANTIATED_MODULES_FOLDER") == "") {
  stop(
    "Please set the INSTANTIATED_MODULES_FOLDER location in your .Rprofile so that Strategus has a known location to store the module files. To do this:
       - Call the function `usethis::edit_r_environ()` to open your .Renviron file
       - Add a line to the .Renviron file: INSTANTIATED_MODULES_FOLDER = 'C:/your/path/to/modules'
       - Close the .Renviron file
       - Restart your R session\n
Once you have completed the steps above, please try running this script again."
  )
}

# Code for running Strategus
analysisSpecifications <-
  ParallelLogger::loadSettingsFromJson("analysisSpecification.json")

# Create and save execution settings ----------------------------------------------------
executionSettings <- Strategus::createCdmExecutionSettings(
  connectionDetailsReference = "my-cdm-connection",
  workDatabaseSchema = "<enter manually to refer to your scratch space>",
  cdmDatabaseSchema = "<enter manually to refer to your CDM schema e.g. database.dbo>",
  cohortTableNames = CohortGenerator::getCohortTableNames("cu_studyathon"),
  workFolder = file.path(getwd(), "strategusWork"),
  resultsFolder = file.path(getwd(), "strategusResults"),
  minCellCount = 5
)

# Save the execution settings in the results folder
ParallelLogger::saveSettingsToJson(executionSettings,
                                   fileName = file.path(getwd(), "executionSettings.json"))

# Execute the study on the database
Strategus::execute(analysisSpecifications = analysisSpecifications,
                   executionSettings = executionSettings)
