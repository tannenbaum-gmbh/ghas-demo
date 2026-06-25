using './main.bicep'

param environmentName = 'ghasdemo'
param location = 'northeurope'
param tags = {
  environment: 'demo'
  project: 'ghas-demo'
  managedBy: 'bicep'
}
