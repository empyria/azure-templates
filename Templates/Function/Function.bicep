@description('The name of the function app that you wish to create.')
param appName string

@description('The name of the app service plan. Leave empty to use App Name.')
param planName string = ''

@description('Use existing app service plan.')
param useExistingAppServicePlan bool = false

@description('The resource group of the existing app service plan if required.')
param planResourceGroup string = ''

@description('Create AppInsights')
param createAppInsights bool = false

@description('The name of the storage account backing the function. Leave empty to use App Name')
@maxLength(24)
param storageAccountName string = ''

@description('Storage Account type')
@allowed([
  'Standard_LRS'
  'Standard_GRS'
  'Standard_RAGRS'
])
param storageAccountType string = 'Standard_LRS'

@description('Location for resources.')
param location string = 'Australia East'

@description('The language worker runtime to load in the function app.')
@allowed([
  'node'
  'dotnet'
  'dotnet-isolated'
  'java'
  'powershell'
])
param runtime string = 'dotnet-isolated'

@allowed([
  '~1'
  '~2'
  '~3'
  '~4'
])
param version string = '~4'

@description('The deployment environments')
@allowed([
  'Test'
  'UAT'
  'Staging'
  'Production'
])
param environment string

@description('User-Assigned Managed Identity name. Leave empty for System Assigned.')
param managedIdentityName string = ''

param additionalAppSettings array = []

var environmentSuffix = ((environment == 'Production') ? '' : '-${toLower(environment)}')
var appName_var = '${appName}${environmentSuffix}'
var planName_var = planName != '' ? planName : appName_var
var storageAccountName_var = storageAccountName == '' ? replace(appName_var, '-', '') : storageAccountName
var functionWorkerRuntime = runtime

var baseAppSettings = union([
    {
      name: 'ASPNETCORE_ENVIRONMENT'
      value: environment
    }
    {
      name: 'AZURE_FUNCTIONS_ENVIRONMENT'
      value: toUpper(environment)
    }
    {
      name: 'AzureWebJobsStorage'
      value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName_var};AccountKey=${listKeys(StorageAccount.id, '2019-06-01').keys[0].value};EndpointSuffix=core.windows.net'
    }
    {
      name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
      value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName_var};AccountKey=${listKeys(StorageAccount.id, '2019-06-01').keys[0].value};EndpointSuffix=core.windows.net'
    }
    {
      name: 'WEBSITE_CONTENTSHARE'
      value: toLower(appName)
    }
    {
      name: 'FUNCTIONS_EXTENSION_VERSION'
      value: version
    }
    {
      name: 'FUNCTIONS_WORKER_RUNTIME'
      value: functionWorkerRuntime
    }
    {
      name: 'AzureWebJobsDisableHomepage'
      value: 'true'
    }
  ], additionalAppSettings)

var managedIdentityName_var = managedIdentityName == '' ? appName_var :  managedIdentityName


var identity = managedIdentityName != '' ? {
  type: 'UserAssigned'
  userAssignedIdentities: {
    '${ManagedIdentity.id}': {}
  }
} : {
  type: 'SystemAssigned'
}

var appInsightsAppSettings = [
  {
    name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
    value: AppInsights.properties.InstrumentationKey
  }
  {
    name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
    value: AppInsights.properties.ConnectionString
  }
]

resource StorageAccount 'Microsoft.Storage/storageAccounts@2019-06-01' = {
  name: storageAccountName_var
  location: location
  kind: 'StorageV2'
  sku: {
    name: storageAccountType
  }
  properties: {
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
  }
}
resource DynamicAppServicePlan 'Microsoft.Web/serverfarms@2021-02-01' = if (!useExistingAppServicePlan) {
  name: planName_var
  location: location
  kind: 'functionapp'
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
  properties: {
    perSiteScaling: false
    elasticScaleEnabled: false
    maximumElasticWorkerCount: 1
    isSpot: false
    reserved: false
    isXenon: false
    hyperV: false
    targetWorkerCount: 0
    targetWorkerSizeId: 0
    zoneRedundant: false
  }
}

resource ExistingAppServicePlan 'Microsoft.Web/serverfarms@2021-02-01' existing = {
  name: planName_var
  scope: resourceGroup(planResourceGroup)
}

resource FunctionApp 'Microsoft.Web/sites@2021-02-01' = {
  name: appName_var
  location: location
  kind: 'functionapp'
  identity: identity
  properties: {
    serverFarmId: useExistingAppServicePlan ? ExistingAppServicePlan.id : DynamicAppServicePlan.id
    siteConfig: {
      appSettings: createAppInsights ? union(baseAppSettings, appInsightsAppSettings) : baseAppSettings

    } 
    keyVaultReferenceIdentity: managedIdentityName != '' ? ManagedIdentity.id : 'SystemAssigned'
  }
}

resource ManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = if (managedIdentityName != '') {
  name: managedIdentityName_var
  location: location
}

resource AppInsights 'Microsoft.Insights/components@2015-05-01' = if (createAppInsights) {
  name: appName_var
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    Request_Source: 'rest'
  }
}
