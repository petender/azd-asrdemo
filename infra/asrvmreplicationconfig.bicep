// Replication Item for Azure Site Recovery Demo
// Enables replication for a VM with specified disks and recovery settings

@description('The resource id of the VM\'s data disk')
param dataDiskResourceId string

@description('The type of managed disk for the data disk')
param dataDiskType string

@description('The resource id of the VM\'s OS disk')
param osDiskResourceId string

@description('The type of managed disk for the os disk')
param osDiskType string

@description('The availability zone to recovery to')
param recoveryAz string

@description('The subnet to recovery the machine to')
param recoverySubnet string

@description('The resource id of the replication container in the recovery region')
param replicationContainerDstId string

@description('The name of the replication container in the source region')
param replicationContainerSrcName string

@description('The name of the replication fabric in the source region')
param replicationFabricSrcName string

@description('The name of the resource group the VM resources will failover to')
param resourceGroupRecoveryName string

@description('The replication policy resource id')
param rsVaultRepPolicyId string

@description('The resource id of the cache storage account')
param storageAccountCacheResId string

@description('The subscription id where the VM resources will failover to')
param subscriptionIdRecovery string = subscription().id

@description('The name of the Recovery Services Vault')
param vaultName string

@description('The name of the VM being enabled for replication')
param vmName string

@description('The resource id of the VM being enabled for replication')
param vmResourceId string

// Reference to existing Recovery Services Vault
resource recoveryVault 'Microsoft.RecoveryServices/vaults@2023-04-01' existing = {
  name: vaultName
}

// Reference to existing replication fabric
resource replicationFabric 'Microsoft.RecoveryServices/vaults/replicationFabrics@2023-04-01' existing = {
  parent: recoveryVault
  name: replicationFabricSrcName
}

// Reference to existing protection container
resource protectionContainer 'Microsoft.RecoveryServices/vaults/replicationFabrics/replicationProtectionContainers@2023-04-01' existing = {
  parent: replicationFabric
  name: replicationContainerSrcName
}

// Replication Protected Item
resource replicationProtectedItem 'Microsoft.RecoveryServices/vaults/replicationFabrics/replicationProtectionContainers/replicationProtectedItems@2023-04-01' = {
  parent: protectionContainer
  name: vmName
  properties: {
    policyId: rsVaultRepPolicyId
    providerSpecificDetails: {
      instanceType: 'A2A'
      fabricObjectId: vmResourceId
      recoveryAvailabilityZone: recoveryAz
      recoveryContainerId: replicationContainerDstId
      recoveryResourceGroupId: '${subscriptionIdRecovery}/resourceGroups/${resourceGroupRecoveryName}'
      recoverySubnetName: recoverySubnet
      vmManagedDisks: [
        {
          diskId: osDiskResourceId
          recoveryResourceGroupId: '${subscriptionIdRecovery}/resourceGroups/${resourceGroupRecoveryName}'
          recoveryReplicaDiskAccountType: osDiskType
          recoveryTargetDiskAccountType: osDiskType
          primaryStagingAzureStorageAccountId: storageAccountCacheResId
        }
        {
          diskId: dataDiskResourceId
          recoveryResourceGroupId: '${subscriptionIdRecovery}/resourceGroups/${resourceGroupRecoveryName}'
          recoveryReplicaDiskAccountType: dataDiskType
          recoveryTargetDiskAccountType: dataDiskType
          primaryStagingAzureStorageAccountId: storageAccountCacheResId
        }
      ]
    }
  }
}
