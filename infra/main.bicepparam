using './main.bicep'

param environmentName = 'ghasdemo'
param location = 'swedencentral'
param aksLocation = 'italynorth'
param tags = {
  environment: 'demo'
  project: 'ghas-demo'
  managedBy: 'bicep'
}
