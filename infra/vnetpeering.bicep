// Secondary VNet Peering for Azure Site Recovery Demo
// Creates peering from secondary VNet to primary VNet

@description('Secondary VNet name')
param SecondaryVNetName string

@description('Secondary peer name')
param vnetpeering2 string

@description('Primary resource group name')
param PrimaryRG string

@description('Primary VNet name')
param PrimaryVNetName string

// Reference to existing secondary VNet
resource wlSecVnet 'Microsoft.Network/virtualNetworks@2023-05-01' existing = {
  name: SecondaryVNetName
}

// Secondary to Primary VNet Peering
resource wlSecVnetPeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-05-01' = {
  parent: wlSecVnet
  name: vnetpeering2
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: true
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: resourceId(PrimaryRG, 'Microsoft.Network/virtualNetworks', PrimaryVNetName)
    }
  }
}
