// Recovery Services Vault for Azure Site Recovery Demo
// Deploys a Recovery Services vault with cache storage account and role assignments

@description('The resource id of the Log Analytics Workspace')
param loganwspace string

@description('The name of the location where the VM resources will be deployed')
param primeLocation string

@description('The name of the location where the VM resources will recover to')
param secLocation string

@description('The tags that will be associated to the resources')
param tags object = {
  environment: 'tdd-asr-demo'
}

@description('Data used to append to resources to ensure uniqueness')
param uniqueData string

// Variables
var storageAccountCacheName = 'asrstcache${uniqueData}'
var vaultName = 'asrvault${uniqueData}'

// Cache Storage Account
resource storageAccountCache 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountCacheName
  location: primeLocation
  tags: tags
  kind: 'Storage'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {}
}

// Recovery Services Vault
resource recoveryVault 'Microsoft.RecoveryServices/vaults@2023-04-01' = {
  name: vaultName
  location: secLocation
  tags: tags
  sku: {
    name: 'RS0'
    tier: 'Standard'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    monitoringSettings: {
      azureMonitorAlertSettings: {
        alertsForAllJobFailures: 'Enabled'
      }
      classicAlertSettings: {
        alertsForCriticalOperations: 'Disabled'
      }
      
    }
    publicNetworkAccess: 'Enabled'
  }
}

// Vault Backup Configuration
resource vaultBackupConfig 'Microsoft.RecoveryServices/vaults/backupconfig@2023-04-01' = {
  parent: recoveryVault
  name: 'vaultconfig'
  properties: {
    enhancedSecurityState: 'Disabled'
    isSoftDeleteFeatureStateEditable: true
    softDeleteFeatureState: 'Disabled'
  }
}

// Vault Storage Configuration
resource vaultStorageConfig 'Microsoft.RecoveryServices/vaults/backupstorageconfig@2023-04-01' = {
  parent: recoveryVault
  name: 'vaultstorageconfig'
  dependsOn: [
    vaultBackupConfig
  ]
  properties: {
    storageModelType: 'ZoneRedundant'
  }
}

// Diagnostic Settings
resource vaultDiagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'sendToWorkspace'
  scope: recoveryVault
  dependsOn: [
    vaultStorageConfig
  ]
  properties: {
    workspaceId: loganwspace
    logs: [
      {
        category: 'AzureSiteRecoveryJobs'
        enabled: true
      }
      {
        category: 'AzureSiteRecoveryEvents'
        enabled: true
      }
      {
        category: 'AzureSiteRecoveryReplicatedItems'
        enabled: true
      }
      {
        category: 'AzureSiteRecoveryReplicationStats'
        enabled: true
      }
      {
        category: 'AzureSiteRecoveryRecoveryPoints'
        enabled: true
      }
      {
        category: 'AzureSiteRecoveryReplicationDataUploadRate'
        enabled: true
      }
      {
        category: 'AddonAzureBackupProtectedInstance'
        enabled: true
      }
      {
        category: 'AzureSiteRecoveryProtectedDiskDataChurn'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

// Role Assignment - Storage Contributor
resource roleAssignmentStorageContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, uniqueData, storageAccountCacheName, 'account')
  scope: storageAccountCache
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c')
    principalId: recoveryVault.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Role Assignment - Storage Blob Data Contributor
resource roleAssignmentStorageBlobContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, uniqueData, storageAccountCacheName, 'blob')
  scope: storageAccountCache
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')
    principalId: recoveryVault.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Outputs
@description('Recovery Services Vault name')
output asrvaultName string = vaultName

@description('Recovery Services Vault principal ID')
output rsVaultPrincipalId string = recoveryVault.identity.principalId

@description('Recovery Services Vault resource ID')
output rsVaultResourceId string = recoveryVault.id

@description('Cache storage account resource ID')
output storageAccountCacheResId string = storageAccountCache.id
