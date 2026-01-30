// =============================================================================
// Neo4j Container App Module
// =============================================================================

@description('Name of the Container App')
param name string

@description('Location for the resource')
param location string = resourceGroup().location

@description('Tags for the resource')
param tags object = {}

@description('Name of the Container Apps Environment')
param containerAppsEnvironmentName string

@secure()
@description('Neo4j Password')
param neo4jPassword string

resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2023-05-01' existing = {
  name: containerAppsEnvironmentName
}

resource neo4j 'Microsoft.App/containerApps@2023-05-01' = {
  name: name
  location: location
  tags: union(tags, { 'azd-service-name': 'neo4j' })
  properties: {
    managedEnvironmentId: containerAppsEnvironment.id
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: false
        targetPort: 7687
        transport: 'tcp'
      }
    }
    template: {
      containers: [
        {
          name: 'neo4j'
          image: 'neo4j:5.15.0'
          resources: {
            cpu: json('1.0')
            memory: '2Gi'
          }
          env: [
            {
              name: 'NEO4J_AUTH'
              value: 'neo4j/${neo4jPassword}'
            }
            {
              name: 'NEO4J_PLUGINS'
              value: '["apoc"]'
            }
            {
              name: 'NEO4J_dbms_security_procedures_unrestricted'
              value: 'apoc.*'
            }
            {
              name: 'NEO4J_dbms_security_procedures_allowlist'
              value: 'apoc.*'
            }
          ]
          // Note: Volume mount removed for demo simplicity
          // Data will not persist across container restarts
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
      // Note: Volumes removed for demo - no persistence
    }
  }
}

output id string = neo4j.id
output name string = neo4j.name
// For internal communication, use the app name directly
output internalHost string = name
