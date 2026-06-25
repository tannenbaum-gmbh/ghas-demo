using './main.bicep'

param environmentName = 'ghasdemo'
param location = 'westeurope'
param tags = {
  environment: 'demo'
  project: 'ghas-demo'
  managedBy: 'bicep'
}
