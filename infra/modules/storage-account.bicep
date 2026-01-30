// =============================================================================
// Storage Account Module with Azure Files
// =============================================================================

@description('Name of the Storage Account')
param name string

@description('Location for the resource')
param location string = resourceGroup().location

@description('Tags for the resource')
param tags object = {}

@description('File shares to create')
param fileShares array = []

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: false
  }
}

resource fileService 'Microsoft.Storage/storageAccounts/fileServices@2023-01-01' = {
  parent: storageAccount
  name: 'default'
}

resource shares 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-01-01' = [for share in fileShares: {
  parent: fileService
  name: share.name
  properties: {
    shareQuota: share.quota
  }
}]

output id string = storageAccount.id
output name string = storageAccount.name
output key string = storageAccount.listKeys().keys[0].value
