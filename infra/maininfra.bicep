// Infrastructure for Azure Site Recovery Demo
// Deploys networking, VMs, bastion host, and replication components

@description('The resource id of the Log Analytics Workspace')
param loganwspace string

@description('The name of the primary region resources will be deployed to')
param primeLocation string

@description('The resource id of the replication policy used for the frontend')
param frontendreplpol string

@description('The resource id of the basic backup policy used for the backend')
param backendreplpol string

@description('The name of the secondary region (must be the paired region)')
param asrvaultName string

@description('The name of the resource group the Recovery Services Vault is in')
param asrvaultRG string

@description('The name of the secondary region the VMs will failover to')
param secLocation string

@description('The name of the resource group in the secondary region')
param secResourceGroupName string

@description('The resource id of the cache storage account')
param storageAccountCacheResId string

@description('The tags that will be associated to the resources')
param tags object = {
  environment: 'tdd-asr-demo'
}


@description('Password for the VMs that are created')
@secure()
param vmAdminPassword string

@description('Administrator name for VMs that are created')
param vmAdminUsername string

// Variables
var availabilityZone = '1'
var bastionName = 'asrbastion'
var bastionPublicIpName = 'asrbastion-pip'
var bastionSubnetName = 'AzureBastionSubnet'
var vmSku = 'Standard_D4s_v5'
var vm1Name = 'asrdemovm1'
var vm1Ip = '10.0.2.5'
var vm2Name = 'asrdemovm2'
var vm2Ip = '10.0.3.5'
var vm3Name = 'asrdemovm3'
var vm3Ip = '10.0.2.10'
var backendsubnetName = 'backendsubnet'
var frontendsubnetName = 'frontendsubnet'
var backendnsgprimeName = 'backendnsg-prime'
var frontendnsgprimeName = 'frontendnsg-prime'
var vnetpeering1 = 'vnetpeeringtosec'
var PrimaryRG = resourceGroup().name
var BastionSubnet = '10.0.1.0/24'
var PrimaryVNet = '10.0.0.0/16'
var PrimaryVNetName = 'primaryvnet'
var backendsubnet = '10.0.3.0/24'
var frontendsubnet = '10.0.2.0/24'
var backendnsgName = 'backendnsg-sec'
var frontendnsgName = 'frontendnsg-sec'
var vnetpeering2 = 'vnetpeeringtopri'
var SecondaryVNet = '10.1.0.0/16'
var SecondaryVNetName = 'secondaryvnet'
var secbackendsubnet = '10.1.2.0/24'
var secfrontendsubnet = '10.1.1.0/24'

// Bastion Public IP
resource bastionPublicIp 'Microsoft.Network/publicIPAddresses@2023-05-01' = {
  name: bastionPublicIpName
  location: primeLocation
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

// Primary Frontend NSG
resource FrontendNSG 'Microsoft.Network/networkSecurityGroups@2023-05-01' = {
  name: frontendnsgprimeName
  location: primeLocation
  tags: tags
  properties: {
    securityRules: []
  }
}

// Primary Backend NSG
resource BackendNSG 'Microsoft.Network/networkSecurityGroups@2023-05-01' = {
  name: backendnsgprimeName
  location: primeLocation
  tags: tags
  properties: {
    securityRules: []
  }
}

// Deploy secondary infrastructure module
module secondaryInfra './asrsecregioninfra.bicep' = {
  name: 'deploysecondaryinfra'
  scope: resourceGroup(secResourceGroupName)
  params: {
    secLocation: secLocation
    tags: tags
    backendnsgName: backendnsgName
    frontendnsgName: frontendnsgName
    SecondaryVNetName: SecondaryVNetName
    SecondaryVNet: SecondaryVNet
    secbackendsubnet: secbackendsubnet
    secfrontendsubnet: secfrontendsubnet
    backendsubnetName: backendsubnetName
    frontendsubnetName: frontendsubnetName
  }
}

// Primary Virtual Network
resource PrimaryVNetresource 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: PrimaryVNetName
  location: primeLocation
  tags: tags
  dependsOn: [
    secondaryInfra
  ]
  properties: {
    addressSpace: {
      addressPrefixes: [
        PrimaryVNet
      ]
    }
    subnets: [
      {
        name: bastionSubnetName
        properties: {
          addressPrefix: BastionSubnet
        }
      }
      {
        name: frontendsubnetName
        properties: {
          addressPrefix: frontendsubnet
          networkSecurityGroup: {
            id: FrontendNSG.id
          }
        }
      }
      {
        name: backendsubnetName
        properties: {
          addressPrefix: backendsubnet
          networkSecurityGroup: {
            id: BackendNSG.id
          }
        }
      }
    ]
    enableDdosProtection: false
  }
}

// Primary to Secondary VNet Peering
resource PrimaryVNetPeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-05-01' = {
  parent: PrimaryVNetresource
  name: vnetpeering1
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: resourceId(secResourceGroupName, 'Microsoft.Network/virtualNetworks', SecondaryVNetName)
    }
  }
}

// Deploy secondary VNet peering
module secVnetPeeringModule './vnetpeering.bicep' = {
  name: 'vnetpeering'
  scope: resourceGroup(secResourceGroupName)
  dependsOn: [
    PrimaryVNetPeering
  ]
  params: {
    SecondaryVNetName: SecondaryVNetName
    vnetpeering2: vnetpeering2
    PrimaryRG: PrimaryRG
    PrimaryVNetName: PrimaryVNetName
  }
}

// Bastion Host
resource bastionHost 'Microsoft.Network/bastionHosts@2023-05-01' = {
  name: bastionName
  location: primeLocation
  tags: tags
  dependsOn: [
    PrimaryVNetresource
    secVnetPeeringModule
  ]
  properties: {
    ipConfigurations: [
      {
        name: 'bastionConfig'
        properties: {
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', PrimaryVNetName, bastionSubnetName)
          }
          publicIPAddress: {
            id: bastionPublicIp.id
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
  }
}

// Bastion Diagnostic Settings
resource bastionDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'SendToWorkspace'
  scope: bastionHost
  properties: {
    workspaceId: loganwspace
    logs: [
      {
        category: 'BastionAuditLogs'
        enabled: true
      }
    ]
    metrics: []
  }
}

// VM 1 Deployment
module vm1Module './windowsvmdeploy.bicep' = {
  name: 'deploy-vm1'
  dependsOn: [
    bastionHost
  ]
  params: {
    adminPassword: vmAdminPassword
    adminUsername: vmAdminUsername
    availabilityZone: availabilityZone
    serverIpAddress: vm1Ip
    myWorkspaceId: reference(loganwspace, '2015-03-20').customerId
    myWorkspaceKey: listKeys(loganwspace, '2015-03-20').primarySharedKey
    subnetName: frontendsubnetName
    tags: tags
    virtualMachineSize: vmSku
    vmName: vm1Name
    vnetName: PrimaryVNetName
  }
}

// VM 2 Deployment
module vm2Module './windowsvmdeploy.bicep' = {
  name: 'deploy-vm2'
  dependsOn: [
    vm1Module
  ]
  params: {
    adminPassword: vmAdminPassword
    adminUsername: vmAdminUsername
    availabilityZone: availabilityZone
    serverIpAddress: vm2Ip
    myWorkspaceId: reference(loganwspace, '2015-03-20').customerId
    myWorkspaceKey: listKeys(loganwspace, '2015-03-20').primarySharedKey
    subnetName: backendsubnetName
    tags: tags
    virtualMachineSize: vmSku
    vmName: vm2Name
    vnetName: PrimaryVNetName
  }
}

// VM 3 Deployment
module vm3Module './windowsvmdeploy.bicep' = {
  name: 'deploy-vm3'
  dependsOn: [
    vm2Module
  ]
  params: {
    adminPassword: vmAdminPassword
    adminUsername: vmAdminUsername
    availabilityZone: availabilityZone
    serverIpAddress: vm3Ip
    myWorkspaceId: reference(loganwspace, '2015-03-20').customerId
    myWorkspaceKey: listKeys(loganwspace, '2015-03-20').primarySharedKey
    subnetName: frontendsubnetName
    tags: tags
    virtualMachineSize: vmSku
    vmName: vm3Name
    vnetName: PrimaryVNetName
  }
}

// Replication Fabric Components
module replicationFabricModule './asrreplicationfabrics.bicep' = {
  name: 'deploy-repl-fabric'
  scope: resourceGroup(asrvaultRG)
  dependsOn: [
    vm3Module
  ]
  params: {
    primeLocation: primeLocation
    backendreplpol: backendreplpol
    frontendreplpol: frontendreplpol
    vnetDstResId: resourceId(secResourceGroupName, 'Microsoft.Network/virtualNetworks', SecondaryVNetName)
    vnetSrcResId: resourceId('Microsoft.Network/virtualNetworks', PrimaryVNetName)
    secLocation: secLocation
    vaultName: asrvaultName
  }
}

// VM 1 Replication
module vm1ReplicationModule './asrvmreplicationconfig.bicep' = {
  name: 'deploy-${vm1Name}-replication'
  scope: resourceGroup(asrvaultRG)
  params: {
    dataDiskResourceId: vm1Module.outputs.dataManagedDiskResId
    dataDiskType: vm1Module.outputs.dataDiskType
    osDiskResourceId: vm1Module.outputs.osManagedDiskResId
    osDiskType: vm1Module.outputs.osDiskType
    recoveryAz: availabilityZone
    recoverySubnet: frontendsubnetName
    replicationContainerDstId: replicationFabricModule.outputs.replicationContainerDstId
    replicationContainerSrcName: replicationFabricModule.outputs.replicationContainerSrcName
    replicationFabricSrcName: replicationFabricModule.outputs.replicationFabricSrcName
    resourceGroupRecoveryName: secResourceGroupName
    rsVaultRepPolicyId: frontendreplpol
    storageAccountCacheResId: storageAccountCacheResId
    vaultName: asrvaultName
    vmName: vm1Name
    vmResourceId: vm1Module.outputs.vmResourceId
  }
}

// VM 2 Replication
module vm2ReplicationModule './asrvmreplicationconfig.bicep' = {
  name: 'deploy-${vm2Name}-replication'
  scope: resourceGroup(asrvaultRG)
  dependsOn: [
    vm1ReplicationModule
  ]
  params: {
    dataDiskResourceId: vm2Module.outputs.dataManagedDiskResId
    dataDiskType: vm2Module.outputs.dataDiskType
    osDiskResourceId: vm2Module.outputs.osManagedDiskResId
    osDiskType: vm2Module.outputs.osDiskType
    recoveryAz: availabilityZone
    recoverySubnet: backendsubnetName
    replicationContainerDstId: replicationFabricModule.outputs.replicationContainerDstId
    replicationContainerSrcName: replicationFabricModule.outputs.replicationContainerSrcName
    replicationFabricSrcName: replicationFabricModule.outputs.replicationFabricSrcName
    resourceGroupRecoveryName: secResourceGroupName
    rsVaultRepPolicyId: backendreplpol
    storageAccountCacheResId: storageAccountCacheResId
    vaultName: asrvaultName
    vmName: vm2Name
    vmResourceId: vm2Module.outputs.vmResourceId
  }
}
