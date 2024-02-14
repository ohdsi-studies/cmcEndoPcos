# -----------------------------------------------------------------
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# -------------->  PLEASE READ THESE INSTRUCTIONS <----------------
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# NOTE: This script is a bit different from the others
# in this template since it is designed with the intent 
# that you would deploy this script to the RConnect shiny server.
# 
# 
# The connection to the OHDA results database is in your OHDA keyring 
# that was setup initially when configuring the Strategus project
# template. Unfortunatley we can't yet use keyring on RConnect so 
# we have to do things a bit differently in this script. To start, 
# if you are running this file on your local machine (or EC2), you
# will need to set up the environment variables by running 
# the code below which is commented out that sets the environment
# variables that we will eventually set on RConnect. Then you can run
# the script without modification below. If you restart your 
# R Session, you may need to re-run the code to re-set the 
# environment variables.
# ------------------------------------------------------------------
options(java.parameters = "-Xss15m")

# Get the study configuration from the config.yml
config <- config::get()

# -----------------------------------------------------------------
# CODE TO RUN IF YOU ARE RUNNING THIS FILE LOCALLY
# (un-comment or just run line by line from the console)
# 
# Strategus:::unlockKeyring(keyringName = config$keyringName)
# Sys.setenv("OHDA_RESULTS_SERVER" = keyring::key_get("resultsServer", keyring = config$keyringName))
# Sys.setenv("OHDA_RESULTS_RO_USER" = keyring::key_get("resultsReadOnlyUser", keyring = config$keyringName))
# Sys.setenv("OHDA_RESULTS_RO_PASSWORD" = keyring::key_get("resultsReadOnlyPassword", keyring = config$keyringName))
#
# -----------------------------------------------------------------



library(ShinyAppBuilder)
library(OhdsiShinyModules)

# Specify the connection to the results database
resultsDatabaseConnectionDetails <- DatabaseConnector::createConnectionDetails(
  dbms = 'postgresql', 
  user = Sys.getenv("OHDA_RESULTS_RO_USER"), 
  password = Sys.getenv("OHDA_RESULTS_RO_PASSWORD"), 
  server = Sys.getenv("OHDA_RESULTS_SERVER")
)

# ADD OR REMOVE MODULES TAILORED TO YOUR STUDY
shinyConfig <- initializeModuleConfig() |>
  addModuleConfig(
    createDefaultAboutConfig()
  )  |>
  addModuleConfig(
    createDefaultDatasourcesConfig()
  )  |>
  addModuleConfig(
    createDefaultCohortGeneratorConfig()
  ) |>
  addModuleConfig(
    createDefaultCohortDiagnosticsConfig()
  ) |>
  addModuleConfig(
    createDefaultCharacterizationConfig()
  ) |>
  addModuleConfig(
    createDefaultPredictionConfig()
  ) |>
  addModuleConfig(
    createDefaultCohortMethodConfig()
  ) |>
  addModuleConfig(
    createDefaultSccsConfig()
  ) |>
  addModuleConfig(
    createDefaultEvidenceSynthesisConfig()
  )

# now create the shiny app based on the config file and view the results
# based on the connection 
ShinyAppBuilder::createShinyApp(
  config = shinyConfig, 
  connectionDetails = resultsDatabaseConnectionDetails,
  resultDatabaseSettings = createDefaultResultDatabaseSettings(schema = config$resultsDatabaseSchema)
)
