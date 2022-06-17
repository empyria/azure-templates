param name string
param location string = 'Australia East'
param environment string
@allowed([
  'standard'
  'free'
])
param sku string = 'standard'
param softDeleteRetentionInDays int = 7
param enablePurgeProtection bool = false

var environmentSuffix = ((environment == 'Production') ? '' : '-${toLower(environment)}')
var baseName = ((environment == 'Prod') ? name : '${name}-${toLower(environment)}')
var qualifiedName = '${baseName}${environmentSuffix}'


resource AppConfiguration 'Microsoft.AppConfiguration/configurationStores@2021-10-01-preview' = {
  name: qualifiedName
  location: location
  sku: {
    name: sku
  }
  properties: {
    encryption: {}
    disableLocalAuth: false
    softDeleteRetentionInDays: softDeleteRetentionInDays
    enablePurgeProtection: enablePurgeProtection
  }
}
