targetScope = 'resourceGroup'

@description('Azure region for all resources.')
param location string = resourceGroup().location

@description('Environment name used as a suffix for resource names.')
@minLength(1)
@maxLength(10)
param environmentName string

@description('Tags to apply to all resources.')
param tags object = {}

@description('Container image tag to deploy for all services.')
param imageTag string = 'latest'

@description('Minimum number of replicas to configure for each container app.')
@minValue(1)
param containerAppMinReplicas int = 1

@description('Maximum number of replicas to configure for each container app.')
@minValue(1)
param containerAppMaxReplicas int = 1

@description('Minimum number of dedicated workload profile instances for the managed environment.')
@minValue(1)
param dedicatedWorkloadProfileMinCount int = 1

@description('Maximum number of dedicated workload profile instances for the managed environment.')
@minValue(1)
param dedicatedWorkloadProfileMaxCount int = 1

// Default resource allocation for each container app
var containerResources = {
  cpu: json('0.25')
  memory: '0.5Gi'
}

// Dedicated workload profile for the container apps environment.
var dedicatedWorkloadProfileName = 'dedicatedWorkloadProfile'
var dedicatedWorkloadProfile = [
  {
    name: dedicatedWorkloadProfileName
    // D4 provides a dedicated compute profile with 4 vCPUs and 16 GiB memory for the container apps environment.
    workloadProfileType: 'D4'
    minimumCount: dedicatedWorkloadProfileMinCount
    maximumCount: dedicatedWorkloadProfileMaxCount
  }
]

var containerAppScaleSettings = {
  minReplicas: containerAppMinReplicas
  maxReplicas: containerAppMaxReplicas
}

// ── User-Assigned Managed Identity ───────────────────────────────────────────

module managedIdentity 'br/public:avm/res/managed-identity/user-assigned-identity:0.4.1' = {
  name: 'managedIdentity'
  params: {
    name: 'id-${environmentName}'
    location: location
    tags: tags
  }
}

// ── Azure Container Registry ──────────────────────────────────────────────────

// Built-in role definition ID for AcrPull
var acrPullRoleDefinitionId = '7f951dda-4ed3-4680-a7ca-43fe172d538d'
var acrName = toLower('cr${replace(replace(environmentName, '-', ''), '_', '')}${uniqueString(resourceGroup().id)}')

module containerRegistry 'br/public:avm/res/container-registry/registry:0.9.1' = {
  name: 'containerRegistry'
  params: {
    name: acrName
    location: location
    tags: tags
    acrSku: 'Basic'
    acrAdminUserEnabled: false
    roleAssignments: [
      {
        principalId: managedIdentity.outputs.principalId
        roleDefinitionIdOrName: acrPullRoleDefinitionId
        principalType: 'ServicePrincipal'
      }
    ]
  }
}

// ── Log Analytics Workspace (required by Container Apps Environment) ──────────

module logAnalyticsWorkspace 'br/public:avm/res/operational-insights/workspace:0.11.1' = {
  name: 'logAnalyticsWorkspace'
  params: {
    name: 'law-${environmentName}'
    location: location
    tags: tags
  }
}

var logAnalyticsDiagnosticSettings = [
  {
    name: 'diag-${environmentName}'
    workspaceResourceId: logAnalyticsWorkspace.outputs.resourceId
    metricCategories: [
      {
        category: 'AllMetrics'
      }
    ]
  }
]

// ── Azure Container Apps Environment ─────────────────────────────────────────

module managedEnvironment 'br/public:avm/res/app/managed-environment:0.13.3' = {
  name: 'managedEnvironment'
  params: {
    name: 'cae-${environmentName}'
    location: location
    tags: tags
    zoneRedundant: false
    workloadProfiles: dedicatedWorkloadProfile
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsWorkspaceResourceId: logAnalyticsWorkspace.outputs.resourceId
    }
  }
}

// ── Container Apps ───────────────────────────────────────────────────────────

module authnApp 'br/public:avm/res/app/container-app:0.22.1' = {
  name: 'authnApp'
  params: {
    name: 'ca-authn-${environmentName}'
    location: location
    tags: tags
    environmentResourceId: managedEnvironment.outputs.resourceId
    managedIdentities: {
      userAssignedResourceIds: [managedIdentity.outputs.resourceId]
    }
    registries: [
      {
        server: containerRegistry.outputs.loginServer
        identity: managedIdentity.outputs.resourceId
      }
    ]
    containers: [
      {
        name: 'authn-service'
        image: '${containerRegistry.outputs.loginServer}/authn-service:${imageTag}'
        resources: containerResources
      }
    ]
    ingressTargetPort: 5000
    ingressExternal: false
    scaleSettings: containerAppScaleSettings
    workloadProfileName: dedicatedWorkloadProfileName
    diagnosticSettings: logAnalyticsDiagnosticSettings
  }
}

module galleryApp 'br/public:avm/res/app/container-app:0.22.1' = {
  name: 'galleryApp'
  params: {
    name: 'ca-gallery-${environmentName}'
    location: location
    tags: tags
    environmentResourceId: managedEnvironment.outputs.resourceId
    managedIdentities: {
      userAssignedResourceIds: [managedIdentity.outputs.resourceId]
    }
    registries: [
      {
        server: containerRegistry.outputs.loginServer
        identity: managedIdentity.outputs.resourceId
      }
    ]
    containers: [
      {
        name: 'gallery-service'
        image: '${containerRegistry.outputs.loginServer}/gallery-service:${imageTag}'
        resources: containerResources
      }
    ]
    ingressTargetPort: 8081
    ingressExternal: false
    scaleSettings: containerAppScaleSettings
    workloadProfileName: dedicatedWorkloadProfileName
    diagnosticSettings: logAnalyticsDiagnosticSettings
  }
}

module storageApp 'br/public:avm/res/app/container-app:0.22.1' = {
  name: 'storageApp'
  params: {
    name: 'ca-storage-${environmentName}'
    location: location
    tags: tags
    environmentResourceId: managedEnvironment.outputs.resourceId
    managedIdentities: {
      userAssignedResourceIds: [managedIdentity.outputs.resourceId]
    }
    registries: [
      {
        server: containerRegistry.outputs.loginServer
        identity: managedIdentity.outputs.resourceId
      }
    ]
    containers: [
      {
        name: 'storage-service'
        image: '${containerRegistry.outputs.loginServer}/storage-service:${imageTag}'
        resources: containerResources
      }
    ]
    ingressTargetPort: 8082
    ingressExternal: false
    scaleSettings: containerAppScaleSettings
    workloadProfileName: dedicatedWorkloadProfileName
    diagnosticSettings: logAnalyticsDiagnosticSettings
  }
}

module frontendApp 'br/public:avm/res/app/container-app:0.22.1' = {
  name: 'frontendApp'
  params: {
    name: 'ca-frontend-${environmentName}'
    location: location
    tags: tags
    environmentResourceId: managedEnvironment.outputs.resourceId
    managedIdentities: {
      userAssignedResourceIds: [managedIdentity.outputs.resourceId]
    }
    registries: [
      {
        server: containerRegistry.outputs.loginServer
        identity: managedIdentity.outputs.resourceId
      }
    ]
    containers: [
      {
        name: 'frontend'
        image: '${containerRegistry.outputs.loginServer}/frontend:${imageTag}'
        resources: containerResources
      }
    ]
    ingressTargetPort: 80
    ingressExternal: true
    scaleSettings: containerAppScaleSettings
    workloadProfileName: dedicatedWorkloadProfileName
    diagnosticSettings: logAnalyticsDiagnosticSettings
  }
}

// ── App Service Plan (B1, Linux) ─────────────────────────────────────────────

var webAppSuffix = take(uniqueString(resourceGroup().id), 8)

module appServicePlan 'br/public:avm/res/web/serverfarm:0.7.0' = {
  name: 'appServicePlan'
  params: {
    name: 'asp-${environmentName}'
    location: location
    tags: tags
    kind: 'linux'
    skuName: 'B1'
    reserved: true
    zoneRedundant: false
  }
}

// ── App Service Web Apps ──────────────────────────────────────────────────────

module authnWebApp 'br/public:avm/res/web/site:0.23.1' = {
  name: 'authnWebApp'
  params: {
    kind: 'app,linux,container'
    name: 'wa-authn-${environmentName}-${webAppSuffix}'
    location: location
    tags: tags
    serverFarmResourceId: appServicePlan.outputs.resourceId
    httpsOnly: true
    managedIdentities: {
      userAssignedResourceIds: [managedIdentity.outputs.resourceId]
    }
    siteConfig: {
      linuxFxVersion: 'DOCKER|${containerRegistry.outputs.loginServer}/authn-service:${imageTag}'
      acrUseManagedIdentityCreds: true
      acrUserManagedIdentityID: managedIdentity.outputs.clientId
      appSettings: [
        {
          name: 'DOCKER_REGISTRY_SERVER_URL'
          value: 'https://${containerRegistry.outputs.loginServer}'
        }
        {
          name: 'WEBSITES_PORT'
          value: '5000'
        }
      ]
    }
    diagnosticSettings: logAnalyticsDiagnosticSettings
  }
}

module galleryWebApp 'br/public:avm/res/web/site:0.23.1' = {
  name: 'galleryWebApp'
  params: {
    kind: 'app,linux,container'
    name: 'wa-gallery-${environmentName}-${webAppSuffix}'
    location: location
    tags: tags
    serverFarmResourceId: appServicePlan.outputs.resourceId
    httpsOnly: true
    managedIdentities: {
      userAssignedResourceIds: [managedIdentity.outputs.resourceId]
    }
    siteConfig: {
      linuxFxVersion: 'DOCKER|${containerRegistry.outputs.loginServer}/gallery-service:${imageTag}'
      acrUseManagedIdentityCreds: true
      acrUserManagedIdentityID: managedIdentity.outputs.clientId
      appSettings: [
        {
          name: 'DOCKER_REGISTRY_SERVER_URL'
          value: 'https://${containerRegistry.outputs.loginServer}'
        }
        {
          name: 'WEBSITES_PORT'
          value: '8081'
        }
      ]
    }
    diagnosticSettings: logAnalyticsDiagnosticSettings
  }
}

module storageWebApp 'br/public:avm/res/web/site:0.23.1' = {
  name: 'storageWebApp'
  params: {
    kind: 'app,linux,container'
    name: 'wa-storage-${environmentName}-${webAppSuffix}'
    location: location
    tags: tags
    serverFarmResourceId: appServicePlan.outputs.resourceId
    httpsOnly: true
    managedIdentities: {
      userAssignedResourceIds: [managedIdentity.outputs.resourceId]
    }
    siteConfig: {
      linuxFxVersion: 'DOCKER|${containerRegistry.outputs.loginServer}/storage-service:${imageTag}'
      acrUseManagedIdentityCreds: true
      acrUserManagedIdentityID: managedIdentity.outputs.clientId
      appSettings: [
        {
          name: 'DOCKER_REGISTRY_SERVER_URL'
          value: 'https://${containerRegistry.outputs.loginServer}'
        }
        {
          name: 'WEBSITES_PORT'
          value: '8082'
        }
      ]
    }
    diagnosticSettings: logAnalyticsDiagnosticSettings
  }
}

module frontendWebApp 'br/public:avm/res/web/site:0.23.1' = {
  name: 'frontendWebApp'
  params: {
    kind: 'app,linux,container'
    name: 'wa-frontend-${environmentName}-${webAppSuffix}'
    location: location
    tags: tags
    serverFarmResourceId: appServicePlan.outputs.resourceId
    httpsOnly: true
    managedIdentities: {
      userAssignedResourceIds: [managedIdentity.outputs.resourceId]
    }
    siteConfig: {
      linuxFxVersion: 'DOCKER|${containerRegistry.outputs.loginServer}/frontend:${imageTag}'
      acrUseManagedIdentityCreds: true
      acrUserManagedIdentityID: managedIdentity.outputs.clientId
      appSettings: [
        {
          name: 'DOCKER_REGISTRY_SERVER_URL'
          value: 'https://${containerRegistry.outputs.loginServer}'
        }
        {
          name: 'WEBSITES_PORT'
          value: '80'
        }
      ]
    }
    diagnosticSettings: logAnalyticsDiagnosticSettings
  }
}

// ── Outputs ───────────────────────────────────────────────────────────────────

@description('Resource ID of the User-Assigned Managed Identity.')
output managedIdentityResourceId string = managedIdentity.outputs.resourceId

@description('Client ID of the User-Assigned Managed Identity.')
output managedIdentityClientId string = managedIdentity.outputs.clientId

@description('Resource ID of the Azure Container Registry.')
output containerRegistryResourceId string = containerRegistry.outputs.resourceId

@description('Login server of the Azure Container Registry.')
output containerRegistryLoginServer string = containerRegistry.outputs.loginServer

@description('Resource ID of the Container Apps Environment.')
output managedEnvironmentResourceId string = managedEnvironment.outputs.resourceId

@description('FQDN of the frontend Container App.')
output frontendFqdn string = frontendApp.outputs.fqdn

@description('Default hostname of the authn App Service Web App.')
output authnWebAppHostname string = authnWebApp.outputs.defaultHostname

@description('Default hostname of the gallery App Service Web App.')
output galleryWebAppHostname string = galleryWebApp.outputs.defaultHostname

@description('Default hostname of the storage App Service Web App.')
output storageWebAppHostname string = storageWebApp.outputs.defaultHostname

@description('Default hostname of the frontend App Service Web App.')
output frontendWebAppHostname string = frontendWebApp.outputs.defaultHostname
