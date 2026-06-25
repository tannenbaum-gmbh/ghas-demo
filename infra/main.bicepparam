using './main.bicep'

param environmentName = 'ghasdemo'
param location = 'swedencentral'
param tags = {
  environment: 'demo'
  project: 'ghas-demo'
  managedBy: 'bicep'
}
