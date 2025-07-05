// Replication Policies for Azure Site Recovery Demo
// Deploys replication policies for frontend and backend VMs

@description('The name of the Recovery Services Vault')
param recSvcVaultName string

// Variables
var repPolicyFeName = 'frontendreplpolicy'
var repPolicyBeName = 'backendreplpolicy'

// Reference to the existing Recovery Services Vault
resource recoveryVault 'Microsoft.RecoveryServices/vaults@2023-04-01' existing = {
  name: recSvcVaultName
}

// Backend Replication Policy
resource replicationPolicyBe 'Microsoft.RecoveryServices/vaults/replicationPolicies@2023-04-01' = {
  parent: recoveryVault
  name: repPolicyBeName
  properties: {
    providerSpecificInput: {
      instanceType: 'A2A'
      appConsistentFrequencyInMinutes: 120
      recoveryPointHistory: 4320
      multiVmSyncStatus: 'Enable'
    }
  }
}

// Frontend Replication Policy
resource replicationPolicyFe 'Microsoft.RecoveryServices/vaults/replicationPolicies@2023-04-01' = {
  parent: recoveryVault
  name: repPolicyFeName
  properties: {
    providerSpecificInput: {
      instanceType: 'A2A'
      recoveryPointHistory: 4320
      multiVmSyncStatus: 'Enable'
    }
  }
}

// Outputs
@description('Backend replication policy name')
output cstRepPolBeName string = repPolicyBeName

@description('Backend replication policy resource ID')
output cstRepPolBeResId string = replicationPolicyBe.id

@description('Frontend replication policy name')
output cstRepPolFeName string = repPolicyFeName

@description('Frontend replication policy resource ID')
output cstRepPolFeResId string = replicationPolicyFe.id
