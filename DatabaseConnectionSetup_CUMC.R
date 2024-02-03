# Step 1

install.packages("DatabaseConnector")
install.packages("usethis")

remotes::install_github(
  repo = "OHDSI/Strategus",
  ref = "v0.2.1"
)

################################################################################
# TEST YOUR DATABASE CONNECTION TO YOUR CDM ------------------
################################################################################
if (Sys.getenv("DATABASECONNECTOR_JAR_FOLDER") == "") {
  # set a env var to a path to store the JDBC drivers
  usethis::edit_r_environ()
  # then add DATABASECONNECTOR_JAR_FOLDER='path/to/jdbc/drivers', save and close
  # Restart your R Session to confirm it worked
  stop("Please add DATABASECONNECTOR_JAR_FOLDER='{path to jdbc driver folder}' to your .Renviron file
       via usethis::edit_r_environ() as instructed, save and then restart R session")
}

DatabaseConnector::downloadJdbcDrivers(
  dbms = "sql server"
)
connectionDetails <- DatabaseConnector::createConnectionDetails(
  dbms = "sql server",
  server = "", # manually enter this
  user = "", # manually enter this
  password = "" # manually enter this
)

# Test the connection
connection <- DatabaseConnector::connect(connectionDetails)
DatabaseConnector::disconnect(connection)

# Store the connection details - Mac users may get prompted for their password
connectionDetailsReference <- "my-cdm-connection"
Strategus::storeConnectionDetails(
  connectionDetails = connectionDetails,
  connectionDetailsReference = connectionDetailsReference
)

# Retrieve the connection details
connectionDetailsFromStrategus <- Strategus::retrieveConnectionDetails(
  connectionDetailsReference = connectionDetailsReference
)

# Test the connection using the connection details from Strategus
connection <- DatabaseConnector::connect(connectionDetailsFromStrategus)
DatabaseConnector::disconnect(connection)