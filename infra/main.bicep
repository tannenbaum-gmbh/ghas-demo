targetScope = 'resourceGroup'

@description('Azure region for all resources.')
param location string = resourceGroup().location

@description('Environment name used as a suffix for resource names.')
@minLength(1)
@maxLength(10)
param environmentName string

@description('Tags to apply to all resources.')
param tags object = {}

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

module containerRegistry 'br/public:avm/res/container-registry/registry:0.9.1' = {
  name: 'containerRegistry'
  params: {
    name: 'cr${environmentName}'
    location: location
    tags: tags
    acrSku: 'Basic'
    adminUserEnabled: false
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
