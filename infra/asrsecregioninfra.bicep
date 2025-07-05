// Secondary Infrastructure for Azure Site Recovery Demo
// Deploys NSGs and VNet in the secondary region

@description('The secondary location')
param secLocation string

@description('The tags that will be associated to the resources')
param tags object

@description('Backend NSG name')
param backendnsgName string

@description('Frontend NSG name')
param frontendnsgName string

@description('Secondary VNet name')
param SecondaryVNetName string

@description('Secondary VNet CIDR')
param SecondaryVNet string

@description('Secondary VNet backend subnet CIDR')
param secbackendsubnet string

@description('Secondary VNet frontend subnet CIDR')
param secfrontendsubnet string

@description('Backend subnet name')
param backendsubnetName string

@description('Frontend subnet name')
param frontendsubnetName string

// Secondary Frontend NSG
resource wlSecFeNsg 'Microsoft.Network/networkSecurityGroups@2023-05-01' = {
  name: frontendnsgName
  location: secLocation
  tags: tags
  properties: {
    securityRules: []
  }
}

// Secondary Backend NSG
resource wlSecBeNsg 'Microsoft.Network/networkSecurityGroups@2023-05-01' = {
  name: backendnsgName
  location: secLocation
  tags: tags
  properties: {
    securityRules: []
  }
}

// Secondary Virtual Network
resource wlSecVnet 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: SecondaryVNetName
  location: secLocation
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        SecondaryVNet
      ]
    }
    subnets: [
      {
        name: frontendsubnetName
        properties: {
          addressPrefix: secfrontendsubnet
          networkSecurityGroup: {
            id: wlSecFeNsg.id
          }
        }
      }
      {
        name: backendsubnetName
        properties: {
          addressPrefix: secbackendsubnet
          networkSecurityGroup: {
            id: wlSecBeNsg.id
          }
        }
      }
    ]
    enableDdosProtection: false
  }
}
