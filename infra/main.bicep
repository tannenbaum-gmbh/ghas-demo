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

// Default resource allocation for each container app
var containerResources = {
  cpu: json('0.25')
  memory: '0.5Gi'
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

// ── Azure Container Apps Environment ─────────────────────────────────────────

module managedEnvironment 'br/public:avm/res/app/managed-environment:0.10.1' = {
  name: 'managedEnvironment'
  params: {
    name: 'cae-${environmentName}'
    location: location
    tags: tags
    logAnalyticsWorkspaceResourceId: logAnalyticsWorkspace.outputs.resourceId
  }
}

// ── Container Apps ───────────────────────────────────────────────────────────

module authnApp 'br/public:avm/res/app/container-app:0.11.0' = {
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
  }
}

module galleryApp 'br/public:avm/res/app/container-app:0.11.0' = {
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
  }
}

module storageApp 'br/public:avm/res/app/container-app:0.11.0' = {
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
  }
}

module frontendApp 'br/public:avm/res/app/container-app:0.11.0' = {
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
