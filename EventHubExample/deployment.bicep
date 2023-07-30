@description('resource location')
param location string = 'westus'

@description('Name of the storage account')
param storageAccountName string = 'akylappstorage'

@description('Name of the function app')
param functionAppName string = 'akylfunc'

var managedIdentityName = '${functionAppName}-identity'
var appInsightsName = '${functionAppName}-appinsights'
var appServicePlanName = '${functionAppName}-appserviceplan'

var blobServiceUri = 'https://${storageAccountName}.blob.core.windows.net/'

var eventHubName = 'akyleventhub'
var eventHubNamespaceName = '${eventHubName}ns'

var storageOwnerRoleDefinitionResourceId = '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/b7e6dc6d-f1e8-4753-8033-0f276bb0955b'
var eventhubDataOwnerRoleId = '/providers/Microsoft.Authorization/roleDefinitions/f526a384-b230-433a-b45c-95f59c4a2dec'


resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: storageAccountName
  location: location
  sku: {
	name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties:{
	  allowBlobPublicAccess: false
  }
}

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: managedIdentityName
  location: location
}

resource storageOwnerPermission 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: guid(storageAccount.id, functionAppName, storageOwnerRoleDefinitionResourceId)
  scope: storageAccount
  properties: {
	principalId: managedIdentity.properties.principalId
	roleDefinitionId: storageOwnerRoleDefinitionResourceId
  }
}


resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
	Application_Type: 'web'
  }
}

resource appServicePlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: appServicePlanName
  location: location
  sku: {
	name: 'Y1'
	tier: 'Dynamic'
  }
}

resource functionApp 'Microsoft.Web/sites@2022-03-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {'${managedIdentity.id}': {}}
  }
  properties: {
	serverFarmId: appServicePlan.id
	siteConfig: {
	  appSettings: [
		{
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
		{
		  name: 'FUNCTIONS_EXTENSION_VERSION'
		  value: '~4'
		}
		{
		  name: 'FUNCTIONS_WORKER_RUNTIME'
		  value: 'dotnet'
		}
		{
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: applicationInsights.properties.InstrumentationKey
        }
		
		{
		  name: 'hubConnection__fullyQualifiedNamespace'
		  value: '${eventHubNamespaceName}.servicebus.windows.net'
		}
		{
		  name: 'hubConnection__credential'
		  value: 'managedidentity'
		}
		{
		  name: 'hubConnection__clientId'
		  value: managedIdentity.properties.clientId
		}
	  ]
	}
  }
}

resource eventHubNamespace 'Microsoft.EventHub/namespaces@2021-11-01' = {
  name: eventHubNamespaceName
  location: location
  sku: {
    name: 'Standard'
    tier: 'Standard'
    capacity: 1
  }
  properties: {
    isAutoInflateEnabled: false
    maximumThroughputUnits: 0
  }
}

resource hubOwnerPermission 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: guid(eventHubNamespace.id, functionAppName, eventhubDataOwnerRoleId)
  scope: eventHubNamespace
  properties: {
	principalId: managedIdentity.properties.principalId
	roleDefinitionId: eventhubDataOwnerRoleId
  }
}

resource eventHub 'Microsoft.EventHub/namespaces/eventhubs@2021-11-01' = {
  parent: eventHubNamespace
  name: eventHubName
  properties: {
    messageRetentionInDays: 7
    partitionCount: 1
  }
}