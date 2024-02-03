# This script is used once to initialize your project

# Check to ensure the default keyring is set up
config <- config::get()
if (!config$keyringName %in% keyring::keyring_list()$keyring) {
  stop("You need to set up your OHDA keyring. 
        Please see https://sourcecode.jnj.com/projects/ITX-ASJ/repos/ohda_keyring_setup/browse for more information.")
}

# Check to make sure environment variable is set for keyring password so 
# it may be unlocked if required.
if (Sys.getenv("STRATEGUS_KEYRING_PASSWORD") == "") {
  stop("You need to set the OHDA keyring password in your .Renviron file. To do this:
        - Run `usethis::edit_r_environ()` to open your .Renviron file
        - Add a line to your .Renviron file: STRATEGUS_KEYRING_PASSWORD='<secret>' (get the real <secret> from someone)
        - Restart your R Session
       See Please see https://sourcecode.jnj.com/projects/ITX-ASJ/repos/ohda_keyring_setup/browse for more information")
}
Strategus:::unlockKeyring(keyringName = config$keyringName)


# TODO: Add mechanism to build study section of for the config.yml? -------


# Get latest CDMs for config.yml ---------------------------------------
webApiUrl <- keyring::key_get("webApiUrl", keyring = config$keyringName) 
ROhdsiWebApi::authorizeWebApi(
  baseUrl = webApiUrl,
  authMethod = "windows"
)

# Get the keyring keys that represent the database connections
library(dplyr)
keyringKeys <- keyring::key_list(keyring = config$keyringName)$service
databaseKeyringKeys <- keyringKeys[startsWith(keyringKeys, prefix = config$keyringConnectionStringPrefix)]
databaseKeyringKeys <- databaseKeyringKeys[order(databaseKeyringKeys)]

# Get a list of latest CDM versions of data sources
cdmSources <- ROhdsiWebApi::getCdmSources(baseUrl = webApiUrl) %>%
  dplyr::filter(!is.na(.data$cdmDatabaseSchema) &
                  startsWith(.data$sourceKey, "cdm_")) %>%
  dplyr::mutate(baseUrl = webApiUrl,
                dbms = 'redshift',
                sourceDialect = 'redshift',
                port = 5439,
                version = .data$sourceKey %>% substr(., nchar(.) - 3, nchar(.)) %>% as.integer(),
                database = .data$sourceKey %>% substr(., 5, nchar(.) - 6)) %>%
  dplyr::group_by(.data$database) %>%
  dplyr::arrange(dplyr::desc(.data$version)) %>%
  dplyr::mutate(sequence = dplyr::row_number()) %>%
  dplyr::ungroup() %>%
  dplyr::arrange(.data$database, .data$sequence) %>%
  dplyr::filter(sequence == 1)

# Iterate over the keyring keys to get the latest CDM schema
latestCdms <- list()
for(databaseKey in databaseKeyringKeys) {
  connectionString <- keyring::key_get(databaseKey, keyring = config$keyringName)
  cdmSchemaRoot <- paste0("cdm_", tail(strsplit(connectionString, "/")[[1]], 1), "_v")
  cdmDatabaseSchema <- cdmSources[startsWith(cdmSources$cdmDatabaseSchema, cdmSchemaRoot), ]$cdmDatabaseSchema[[1]]
  configKey <- substr(databaseKey, nchar(config$keyringConnectionStringPrefix)+1, nchar(databaseKey))
  latestCdms[[configKey]] <- cdmDatabaseSchema
}

yamlFile <- "config.yml"
yamlConfig <- readLines(yamlFile)
findPatternTemplate <- "^  %s:.*$"
replacementPatternTemplate <- "  %s: %s"
for (i in seq_along(latestCdms)) {
  yamlConfig <- gsub(
    pattern = sprintf(findPatternTemplate, names(latestCdms)[i]), 
    replacement = sprintf(replacementPatternTemplate, names(latestCdms)[i], latestCdms[[i]]),
    yamlConfig
  )
}
cat(yamlConfig, sep = "\n", file = yamlFile)