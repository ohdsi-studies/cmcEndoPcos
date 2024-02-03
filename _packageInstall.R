# This script is used once to initialize your project

# Make sure the necessary packages are installed
dynamic_require <- function(...){
  origVal <- getOption("install.packages.compile.from.source")
  options(install.packages.compile.from.source = "never")
  on.exit(options(install.packages.compile.from.source = origVal))
  libs<-unlist(list(...))
  for (package in libs) {
    remotePackage <- grepl("/", package)
    packageRef <- grepl("@", package)
    packageRoot <- ifelse(remotePackage, strsplit(x = package, "/")[[1]][2], package)
    packageRoot <- ifelse(packageRef, strsplit(x = packageRoot, "@")[[1]][1], packageRoot)
    packageRef <- ifelse(packageRef, strsplit(x = package, "@")[[1]][2], "HEAD")
    if(eval(parse(text=paste("require(",packageRoot,", quietly = TRUE)"))) == FALSE) {
      message(paste0("Installing: ", package))
      if (remotePackage) {
        require("remotes")
        remotes::install_github(repo = package, ref = packageRef)
      } else {
        install.packages(package)
      }
    } else {
      message(paste0(package, " already installed"))
      detach(pos = match(paste("package", packageRoot, sep = ":"), search()))
    }
  }
}

dynamic_require(
  "usethis",
  "remotes",
  "config",
  "dplyr",
  "readr",
  "ohdsi/DatabaseConnector",
  "ohdsi/FeatureExtraction",
  "ohdsi/ParallelLogger",
  "ohdsi/SqlRender",
  "ohdsi/ROhdsiWebApi",
  "ohdsi/Strategus",
  "ohdsi/PheValuator",
  "ohdsi/ResultModelManager",
  "ohdsi/CohortDiagnostics",
  "ohdsi/CohortGenerator",
  "ohdsi/Characterization",
  "ohdsi/CohortIncidence",
  "ohdsi/CohortMethod",
  "ohdsi/SelfControlledCaseSeries",
  "ohdsi/PatientLevelPrediction",
  "ohdsi/EvidenceSynthesis",
  "ohdsi/DbDiagnostics",
  "ohdsi/Strategus@develop",
  "ohdsi/ShinyAppBuilder@develop",
  "ohdsi/OhdsiShinyModules@develop",
  "ohdsi/ProtocolGenerator"
)

rstudioapi::restartSession()