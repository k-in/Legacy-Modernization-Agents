// =============================================================================
// Main Bicep Template - COBOL Migration Demo
// Azure Container Apps Environment with Neo4j and McpChatWeb
// =============================================================================

targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the environment (e.g., dev, staging, prod)')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

// Azure OpenAI Configuration
@description('Azure OpenAI Endpoint URL')
param azureOpenAiEndpoint string = ''

@secure()
@description('Azure OpenAI API Key')
param azureOpenAiApiKey string = ''

@description('Azure OpenAI Deployment Name')
param azureOpenAiDeploymentName string = ''

@description('Azure OpenAI Model ID')
param azureOpenAiModelId string = 'gpt-4o'

// Neo4j Configuration
@secure()
@description('Neo4j Password')
param neo4jPassword string = 'cobol-migration-2025'

// Tags
var tags = {
  'azd-env-name': environmentName
  'application': 'cobol-migration-demo'
}

// Abbreviations for naming
var abbrs = loadJsonContent('./abbreviations.json')
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))

// Resource Group
resource rg 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: 'rg-${environmentName}'
  location: location
  tags: tags
}

// Log Analytics Workspace
module logAnalytics 'modules/log-analytics.bicep' = {
  name: 'log-analytics'
  scope: rg
  params: {
    name: '${abbrs.operationalInsightsWorkspaces}${resourceToken}'
    location: location
    tags: tags
  }
}

// Azure Container Registry
module containerRegistry 'modules/container-registry.bicep' = {
  name: 'container-registry'
  scope: rg
  params: {
    name: '${abbrs.containerRegistryRegistries}${resourceToken}'
    location: location
    tags: tags
  }
}

// Storage Account for Azure Files (SQLite + Neo4j data persistence)
module storageAccount 'modules/storage-account.bicep' = {
  name: 'storage-account'
  scope: rg
  params: {
    name: '${abbrs.storageStorageAccounts}${resourceToken}'
    location: location
    tags: tags
    fileShares: [
      {
        name: 'neo4j-data'
        quota: 5
      }
      {
        name: 'app-data'
        quota: 1
      }
    ]
  }
}

// Container Apps Environment
module containerAppsEnvironment 'modules/container-apps-environment.bicep' = {
  name: 'container-apps-environment'
  scope: rg
  params: {
    name: '${abbrs.appManagedEnvironments}${resourceToken}'
    location: location
    tags: tags
    logAnalyticsWorkspaceName: logAnalytics.outputs.name
    storageAccountName: storageAccount.outputs.name
    storageAccountKey: storageAccount.outputs.key
    fileShares: [
      {
        name: 'neo4j-data'
        shareName: 'neo4j-data'
      }
      {
        name: 'app-data'
        shareName: 'app-data'
      }
    ]
  }
}

// Neo4j Container App
module neo4j 'modules/neo4j.bicep' = {
  name: 'neo4j'
  scope: rg
  params: {
    name: 'neo4j'
    location: location
    tags: tags
    containerAppsEnvironmentName: containerAppsEnvironment.outputs.name
    neo4jPassword: neo4jPassword
  }
}

// McpChatWeb Container App
module mcpChatWeb 'modules/mcpchatweb.bicep' = {
  name: 'mcpchatweb'
  scope: rg
  params: {
    name: 'mcpchatweb'
    location: location
    tags: tags
    containerAppsEnvironmentName: containerAppsEnvironment.outputs.name
    containerRegistryName: containerRegistry.outputs.name
    imageName: 'mcpchatweb:${environmentName}'
    // Use a small placeholder image during initial provisioning.
    // azd deploy will later build/push the real image to ACR and update the container app.
    provisioningImage: 'hashicorp/http-echo:0.2.3'
    neo4jHost: neo4j.outputs.internalHost
    neo4jPassword: neo4jPassword
    azureOpenAiEndpoint: azureOpenAiEndpoint
    azureOpenAiApiKey: azureOpenAiApiKey
    azureOpenAiDeploymentName: azureOpenAiDeploymentName
    azureOpenAiModelId: azureOpenAiModelId
  }
}

// Outputs
output AZURE_LOCATION string = location
output AZURE_TENANT_ID string = tenant().tenantId
output AZURE_RESOURCE_GROUP string = rg.name
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = containerRegistry.outputs.loginServer
output AZURE_CONTAINER_REGISTRY_NAME string = containerRegistry.outputs.name
output SERVICE_MCPCHATWEB_NAME string = mcpChatWeb.outputs.name
output SERVICE_MCPCHATWEB_URI string = mcpChatWeb.outputs.uri
output NEO4J_INTERNAL_HOST string = neo4j.outputs.internalHost
