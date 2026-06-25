targetScope = 'resourceGroup'

@description('Azure region for all resources.')
param location string = resourceGroup().location

@description('Environment name used as a suffix for resource names.')
@minLength(1)
@maxLength(10)
param environmentName string

@description('Tags to apply to all resources.')
param tags object = {}

// ── Azure Container Registry ──────────────────────────────────────────────────

module containerRegistry 'br/public:avm/res/container-registry/registry:0.9.1' = {
  name: 'containerRegistry'
  params: {
    name: 'cr${environmentName}'
    location: location
    tags: tags
    acrSku: 'Basic'
    adminUserEnabled: false
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

// ── Outputs ───────────────────────────────────────────────────────────────────

@description('Resource ID of the Azure Container Registry.')
output containerRegistryResourceId string = containerRegistry.outputs.resourceId

@description('Login server of the Azure Container Registry.')
output containerRegistryLoginServer string = containerRegistry.outputs.loginServer

@description('Resource ID of the Container Apps Environment.')
output managedEnvironmentResourceId string = managedEnvironment.outputs.resourceId
