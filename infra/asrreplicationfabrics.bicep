// Replication Components for Azure Site Recovery Demo
// Deploys replication fabrics, containers, mappings, and network mappings

@description('The name of the location where the VM resources will be deployed')
param primeLocation string

@description('The resource id of the backend replication policy')
param backendreplpol string

@description('The resource id of the frontend replication policy')
param frontendreplpol string

@description('The resource id of the vnet the VM resources will be recover to')
param vnetDstResId string

@description('The resource id of the vnet the VM resources will be deployed to')
param vnetSrcResId string

@description('The name of the location where the VM resources will recover to')
param secLocation string

@description('The name of the Recover Services Vault')
param vaultName string

// Variables
var replA2ABeMappingFailover = 'a2aberecovery-centralus'
var replA2ABeMappingFailBack = 'a2abefailback-eastus2'
var replA2AFeMappingFailover = 'a2arecovery-centralus'
var replA2AFeMappingFailBack = 'a2afailback-eastus2'
var replA2AFabricContDst = 'a2areplcon-eastus2'
var replA2AFabricContSrc = 'a2areplcon-centralus'
var replA2AFabricObjDst = '${secLocation}-a2afabric'
var replA2AFabricObjSrc = '${primeLocation}-a2afabric'
var replNetworkMappingSrc = 'a2acentustoeastus2nwmap'
var replNetworkMappingDst = 'a2aeastus2tocentusnwmap'

// Reference to existing Recovery Services Vault
resource recoveryVault 'Microsoft.RecoveryServices/vaults@2023-04-01' existing = {
  name: vaultName
}

// Source Replication Fabric
resource replicationFabricSrc 'Microsoft.RecoveryServices/vaults/replicationFabrics@2023-04-01' = {
  parent: recoveryVault
  name: replA2AFabricObjSrc
  properties: {
    customDetails: {
      instanceType: 'Azure'
      location: primeLocation
    }
  }
}

// Destination Replication Fabric
resource replicationFabricDst 'Microsoft.RecoveryServices/vaults/replicationFabrics@2023-04-01' = {
  parent: recoveryVault
  name: replA2AFabricObjDst
  dependsOn: [
    replicationFabricSrc
  ]
  properties: {
    customDetails: {
      instanceType: 'Azure'
      location: secLocation
    }
  }
}

// Source Protection Container
resource protectionContainerSrc 'Microsoft.RecoveryServices/vaults/replicationFabrics/replicationProtectionContainers@2023-04-01' = {
  parent: replicationFabricSrc
  name: replA2AFabricContSrc
  dependsOn: [
    replicationFabricDst
  ]
  properties: {
    providerSpecificInput: [
      {
        instanceType: 'A2A'
      }
    ]
  }
}

// Destination Protection Container
resource protectionContainerDst 'Microsoft.RecoveryServices/vaults/replicationFabrics/replicationProtectionContainers@2023-04-01' = {
  parent: replicationFabricDst
  name: replA2AFabricContDst
  dependsOn: [
    protectionContainerSrc
  ]
  properties: {
    providerSpecificInput: [
      {
        instanceType: 'A2A'
      }
    ]
  }
}

// Frontend Mapping Failover
resource feMappingFailover 'Microsoft.RecoveryServices/vaults/replicationFabrics/replicationProtectionContainers/replicationProtectionContainerMappings@2023-04-01' = {
  parent: protectionContainerSrc
  name: replA2AFeMappingFailover
  properties: {
    policyId: frontendreplpol
    providerSpecificInput: {
      instanceType: 'A2A'
      agentAutoUpdateStatus: 'Disabled'
    }
    targetProtectionContainerId: protectionContainerDst.id
  }
}

// Frontend Mapping Failback
resource feMappingFailback 'Microsoft.RecoveryServices/vaults/replicationFabrics/replicationProtectionContainers/replicationProtectionContainerMappings@2023-04-01' = {
  parent: protectionContainerDst
  name: replA2AFeMappingFailBack
  dependsOn: [
    feMappingFailover
  ]
  properties: {
    policyId: frontendreplpol
    providerSpecificInput: {
      instanceType: 'A2A'
      agentAutoUpdateStatus: 'Disabled'
    }
    targetProtectionContainerId: protectionContainerSrc.id
  }
}

// Backend Mapping Failover
resource beMappingFailover 'Microsoft.RecoveryServices/vaults/replicationFabrics/replicationProtectionContainers/replicationProtectionContainerMappings@2023-04-01' = {
  parent: protectionContainerSrc
  name: replA2ABeMappingFailover
  properties: {
    policyId: backendreplpol
    providerSpecificInput: {
      instanceType: 'A2A'
      agentAutoUpdateStatus: 'Disabled'
    }
    targetProtectionContainerId: protectionContainerDst.id
  }
}

// Backend Mapping Failback
resource beMappingFailback 'Microsoft.RecoveryServices/vaults/replicationFabrics/replicationProtectionContainers/replicationProtectionContainerMappings@2023-04-01' = {
  parent: protectionContainerDst
  name: replA2ABeMappingFailBack
  dependsOn: [
    beMappingFailover
  ]
  properties: {
    policyId: backendreplpol
    providerSpecificInput: {
      instanceType: 'A2A'
      agentAutoUpdateStatus: 'Disabled'
    }
    targetProtectionContainerId: protectionContainerSrc.id
  }
}

// Network Mapping Source to Destination
resource networkMappingSrc 'Microsoft.RecoveryServices/vaults/replicationFabrics/replicationNetworks/replicationNetworkMappings@2023-04-01' = {
  name: replNetworkMappingSrc
  parent: replicationNetworkSrc
  dependsOn: [
    beMappingFailback
  ]
  properties: {
    fabricSpecificDetails: {
      instanceType: 'AzureToAzure'
      primaryNetworkId: vnetSrcResId
    }
    recoveryFabricName: replA2AFabricObjDst
    recoveryNetworkId: vnetDstResId
  }
}

// Azure Network for Source Fabric
resource replicationNetworkSrc 'Microsoft.RecoveryServices/vaults/replicationFabrics/replicationNetworks@2023-04-01' existing = {
  parent: replicationFabricSrc
  name: 'azureNetwork'
}

// Azure Network for Destination Fabric
resource replicationNetworkDst 'Microsoft.RecoveryServices/vaults/replicationFabrics/replicationNetworks@2023-04-01' existing = {
  parent: replicationFabricDst
  name: 'azureNetwork'
}

// Network Mapping Destination to Source
resource networkMappingDst 'Microsoft.RecoveryServices/vaults/replicationFabrics/replicationNetworks/replicationNetworkMappings@2023-04-01' = {
  name: replNetworkMappingDst
  parent: replicationNetworkDst
  dependsOn: [
    networkMappingSrc
  ]
  properties: {
    fabricSpecificDetails: {
      instanceType: 'AzureToAzure'
      primaryNetworkId: vnetDstResId
    }
    recoveryFabricName: replA2AFabricObjSrc
    recoveryNetworkId: vnetSrcResId
  }
}

// Outputs
@description('Destination replication container ID')
output replicationContainerDstId string = protectionContainerDst.id

@description('Source replication container name')
output replicationContainerSrcName string = replA2AFabricContSrc

@description('Source replication fabric name')
output replicationFabricSrcName string = replA2AFabricObjSrc
