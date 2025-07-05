// Log Analytics Workspace for Azure Site Recovery Demo
// Deploys a Log Analytics workspace for monitoring and diagnostics

@description('The tags that will be associated to the resources')
param tags object = {
  environment: 'tdd-asr-demo'
}

// Variables
var laWorkspaceName = 'asrloganalytics'
var location = resourceGroup().location

// Log Analytics Workspace
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: laWorkspaceName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

// Outputs
@description('Log Analytics workspace name')
output logAnalyticsName string = laWorkspaceName

@description('Log Analytics workspace resource ID')
output logAnalyticsResourceId string = logAnalyticsWorkspace.id

@description('Log Analytics workspace ID')
output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.properties.customerId
