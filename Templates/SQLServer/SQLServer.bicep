@description('The deployment environments')
@allowed([
  'Test'
  'UAT'
  'Staging'
  'Production'
])
param environment string

param administratorLogin string = ''
@secure()
param administratorLoginPassword string = ''
param administrators object = {}
param location string
param serverName string

var environmentSuffix = ((environment == 'Production') ? '' : '-${toLower(environment)}')
var serverName_var = '${serverName}${environmentSuffix}'

resource Server 'Microsoft.Sql/servers@2021-02-01-preview' = {
  name: serverName_var  
  location: location  
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorLoginPassword
    administrators: administrators
    version: '12.0'
    minimalTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'
    restrictOutboundNetworkAccess: 'Disabled'
  }
}
