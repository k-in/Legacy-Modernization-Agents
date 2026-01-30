// =============================================================================
// McpChatWeb Container App Module
// =============================================================================

@description('Name of the Container App')
param name string

@description('Location for the resource')
param location string = resourceGroup().location

@description('Tags for the resource')
param tags object = {}

@description('Name of the Container Apps Environment')
param containerAppsEnvironmentName string

@description('Name of the Container Registry')
param containerRegistryName string

@description('Container image name')
param imageName string

@description('Optional container image to use during initial provisioning (must be a valid image reference). When set, it will be used instead of the ACR image. Intended to avoid provision failures before the app image is pushed to ACR.')
param provisioningImage string = ''

@description('Neo4j host FQDN')
param neo4jHost string

@secure()
@description('Neo4j Password')
param neo4jPassword string

@description('Azure OpenAI Endpoint')
param azureOpenAiEndpoint string = ''

@secure()
@description('Azure OpenAI API Key')
param azureOpenAiApiKey string = ''

@description('Azure OpenAI Deployment Name')
param azureOpenAiDeploymentName string = ''

@description('Azure OpenAI Model ID')
param azureOpenAiModelId string = 'gpt-4o'

resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2023-05-01' existing = {
  name: containerAppsEnvironmentName
}

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = {
  name: containerRegistryName
}

var resolvedImage = empty(provisioningImage)
  ? '${containerRegistry.properties.loginServer}/${imageName}'
  : provisioningImage

var containerBase = {
  name: 'mcpchatweb'
  image: resolvedImage
  resources: {
    cpu: json('0.5')
    memory: '1Gi'
  }
  env: [
    {
      name: 'ASPNETCORE_ENVIRONMENT'
      value: 'Production'
    }
    {
      name: 'ASPNETCORE_URLS'
      value: 'http://+:5028'
    }
    {
      name: 'ApplicationSettings__MigrationDatabasePath'
      value: '/app/Data/migration.db'
    }
    {
      name: 'ApplicationSettings__Neo4j__Enabled'
      value: 'true'
    }
    {
      name: 'ApplicationSettings__Neo4j__Uri'
      value: 'bolt://${neo4jHost}:7687'
    }
    {
      name: 'ApplicationSettings__Neo4j__Username'
      value: 'neo4j'
    }
    {
      name: 'ApplicationSettings__Neo4j__Password'
      secretRef: 'neo4j-password'
    }
    {
      name: 'ApplicationSettings__Neo4j__Database'
      value: 'neo4j'
    }
    {
      name: 'AZURE_OPENAI_ENDPOINT'
      value: azureOpenAiEndpoint
    }
    {
      name: 'AZURE_OPENAI_API_KEY'
      secretRef: 'openai-api-key'
    }
    {
      name: 'AZURE_OPENAI_DEPLOYMENT_NAME'
      value: azureOpenAiDeploymentName
    }
    {
      name: 'AZURE_OPENAI_MODEL_ID'
      value: azureOpenAiModelId
    }
  ]
}

var provisioningOverrides = empty(provisioningImage) ? {} : {
  // Use a tiny HTTP server placeholder that binds to the same port as the real app.
  // This keeps Container App revision provisioning healthy until azd deploy updates the image.
  args: [
    '-listen=:5028'
    '-text=Provisioned. Waiting for deployment.'
  ]
}

resource mcpChatWeb 'Microsoft.App/containerApps@2023-05-01' = {
  name: name
  location: location
  tags: union(tags, { 'azd-service-name': 'mcpchatweb' })
  properties: {
    managedEnvironmentId: containerAppsEnvironment.id
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: true
        targetPort: 5028
        transport: 'http'
        allowInsecure: false
      }
      registries: [
        {
          server: containerRegistry.properties.loginServer
          username: containerRegistry.listCredentials().username
          passwordSecretRef: 'registry-password'
        }
      ]
      secrets: [
        {
          name: 'registry-password'
          value: containerRegistry.listCredentials().passwords[0].value
        }
        {
          name: 'neo4j-password'
          value: neo4jPassword
        }
        {
          name: 'openai-api-key'
          value: azureOpenAiApiKey
        }
      ]
    }
    template: {
      containers: [
        union(containerBase, provisioningOverrides)
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 3
        rules: [
          {
            name: 'http-scaling'
            http: {
              metadata: {
                concurrentRequests: '10'
              }
            }
          }
        ]
      }
      // Note: Volumes removed for demo - data is embedded in the Docker image
    }
  }
}

output id string = mcpChatWeb.id
output name string = mcpChatWeb.name
output uri string = 'https://${mcpChatWeb.properties.configuration.ingress.fqdn}'
