// =============================================================================
// Container Apps Environment Module
// =============================================================================

@description('Name of the Container Apps Environment')
param name string

@description('Location for the resource')
param location string = resourceGroup().location

@description('Tags for the resource')
param tags object = {}

@description('Name of the Log Analytics workspace')
param logAnalyticsWorkspaceName string

@description('Name of the Storage Account for file shares')
param storageAccountName string

@description('Storage Account Key')
@secure()
param storageAccountKey string

@description('File shares to mount')
param fileShares array = []

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: logAnalyticsWorkspaceName
}

resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2023-05-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsWorkspace.properties.customerId
        sharedKey: logAnalyticsWorkspace.listKeys().primarySharedKey
      }
    }
  }
}

// Storage mounts for persistence
resource storages 'Microsoft.App/managedEnvironments/storages@2023-05-01' = [for share in fileShares: {
  parent: containerAppsEnvironment
  name: share.name
  properties: {
    azureFile: {
      accountName: storageAccountName
      accountKey: storageAccountKey
      shareName: share.shareName
      accessMode: 'ReadWrite'
    }
  }
}]

output id string = containerAppsEnvironment.id
output name string = containerAppsEnvironment.name
output defaultDomain string = containerAppsEnvironment.properties.defaultDomain
