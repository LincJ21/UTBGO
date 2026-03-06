// ─────────────────────────────────────────────────────────
// UTBGO — Azure Bicep Template
// Despliegue de Infraestructura para Azure Container Apps
// ─────────────────────────────────────────────────────────

param location string = resourceGroup().location
param environmentName string = 'utbgo-env'
param logAnalyticsName string = 'utbgo-logs'
param containerRegistryName string = 'utbgoregistry${uniqueString(resourceGroup().id)}'

// 1. Log Analytics (Para monitoreo)
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
  }
}

// 2. Container Registry (Donde vivirán tus imágenes)
resource acr 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' = {
  name: containerRegistryName
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: true
  }
}

// 3. Container Apps Environment (La red privada compartida)
resource env 'Microsoft.App/managedEnvironments@2022-10-01' = {
  name: environmentName
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalytics.properties.customerId
        sharedKey: logAnalytics.listKeys().primarySharedKey
      }
    }
  }
}

// 4. Ejemplo: API Principal (Solo estructura, el despliegue final usa 'az containerapp up')
resource apiApp 'Microsoft.App/containerApps@2022-10-01' = {
  name: 'utbgo-api'
  location: location
  properties: {
    managedEnvironmentId: env.id
    configuration: {
      ingress: {
        external: true
        targetPort: 8080
      }
      secrets: [
        {
          name: 'db-connection'
          value: 'REEMPLAZAR_CON_VALOR_REAL'
        }
      ]
    }
    template: {
      containers: [
        {
          image: '${acr.name}.azurecr.io/utbgo-api:latest'
          name: 'utbgo-api'
          resources: {
            cpu: json('0.5')
            memory: '1.0Gi'
          }
          env: [
            {
              name: 'GIN_MODE'
              value: 'release'
            }
            {
              name: 'DB_CONNECTION_STRING'
              secretRef: 'db-connection'
            }
          ]
        }
      ]
    }
  }
}

output acrName string = acr.name
output envId string = env.id
