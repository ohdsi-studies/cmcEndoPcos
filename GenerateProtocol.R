# If it is not already installed, install the OHDSI ProtocolGenerator package
# remotes::install_github("OHDSI/ProtocolGenerator")

# set the rootFolder to be the project directory
rootFolder <- getwd()

# Generating the protocol for the Endometriosis Characterization Question

ProtocolGenerator::generateProtocol(
  jsonLocation = file.path(rootFolder, "analysisSpecificationEndometriosisCharacterization.json"), 
  webAPI = "https://api.ohdsi.org/WebAPI", 
  outputLocation = file.path(rootFolder, 'protocol'), 
  outputName = 'analysisProtocolEndometriosisCharacterization.html'
)

# Generating the protocol for the PCOS Incidence Question

ProtocolGenerator::generateProtocol(
  jsonLocation = file.path(rootFolder, "analysisSpecificationPcosIncidence.json"), 
  webAPI = "https://api.ohdsi.org/WebAPI", 
  outputLocation = file.path(rootFolder, 'protocol'), 
  outputName = 'analysisProtocolPcosIncidence.html'
)

# Generating the protocol for the PCOS Prediction Question

ProtocolGenerator::generateProtocol(
  jsonLocation = file.path(rootFolder, "analysisSpecificationPcosPrediction.json"), 
  webAPI = "https://api.ohdsi.org/WebAPI", 
  outputLocation = file.path(rootFolder, 'protocol'), 
  outputName = 'analysisProtocolPcosPrediction.html'
)
