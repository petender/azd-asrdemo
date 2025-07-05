// Windows VM for Azure Site Recovery Demo
// Deploys a Windows VM with monitoring extensions and custom configuration

@description('The password for the administrator account created on the VM')
@secure()
param adminPassword string

@description('Name of the administrator account created on the VM')
param adminUsername string

@description('The number of the availability zone to deploy to')
param availabilityZone string

@description('The Log and Analytics workspace ID that the Microsoft Monitoring Agent will deliver metrics and logs to')
param myWorkspaceId string

@description('The Log and Analytics workspace secret')
@secure()
param myWorkspaceKey string

@description('The subnet within the Virtual Network the network interface for the VM is to be placed in')
param subnetName string

@description('The static IP address assigned to the server\'s network interface')
param serverIpAddress string

@description('The tags that will be associated to the VM')
param tags object

@description('VM Size')
param virtualMachineSize string

@description('VM Name')
param vmName string

@description('The Virtual Network the VM is to be placed in')
param vnetName string

@description('The resource group of the Virtual Network the VM will use')
param vnetResourceGroup string = resourceGroup().name

@description('The subscription of the Virtual Network the VM will use')
param vnetSubscriptionId string = subscription().subscriptionId

// Variables
var location = resourceGroup().location
var nicName = '${vmName}nic'
var dataDiskType = 'StandardSSD_LRS'
var osDiskType = 'StandardSSD_LRS'
var subnetRef = resourceId(vnetSubscriptionId, vnetResourceGroup, 'Microsoft.Network/virtualNetworks/subnets', vnetName, subnetName)

// Network Interface
resource networkInterface 'Microsoft.Network/networkInterfaces@2023-05-01' = {
  name: nicName
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Static'
          privateIPAddress: serverIpAddress
          subnet: {
            id: subnetRef
          }
        }
      }
    ]
  }
}

// Virtual Machine
resource virtualMachine 'Microsoft.Compute/virtualMachines@2023-07-01' = {
  name: vmName
  location: location
  tags: tags
  zones: [availabilityZone]
  properties: {
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
    hardwareProfile: {
      vmSize: virtualMachineSize
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterface.id
        }
      ]
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPassword
      windowsConfiguration: {
        enableAutomaticUpdates: true
        provisionVMAgent: true
      }
    }
    storageProfile: {
      dataDisks: [
        {
          name: '${vmName}_data-disk1'
          caching: 'None'
          diskSizeGB: 1
          lun: 0
          createOption: 'Empty'
          managedDisk: {
            storageAccountType: dataDiskType
          }
        }
      ]
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: osDiskType
        }
      }
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2019-Datacenter'
        version: 'latest'
      }
    }
  }
}

// Dependency Agent Extension
resource dependencyAgentExtension 'Microsoft.Compute/virtualMachines/extensions@2023-07-01' = {
  parent: virtualMachine
  name: 'DependencyAgentWindows'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Monitoring.DependencyAgent'
    type: 'DependencyAgentWindows'
    typeHandlerVersion: '9.5'
    autoUpgradeMinorVersion: true
  }
}

// Microsoft Monitoring Agent Extension
resource mmaExtension 'Microsoft.Compute/virtualMachines/extensions@2023-07-01' = {
  parent: virtualMachine
  name: 'MMAExtension'
  location: location
  dependsOn: [
    dependencyAgentExtension
  ]
  properties: {
    publisher: 'Microsoft.EnterpriseCloud.Monitoring'
    type: 'MicrosoftMonitoringAgent'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
    settings: {
      workspaceId: myWorkspaceId
      stopOnMultipleConnections: true
    }
    protectedSettings: {
      workspaceKey: myWorkspaceKey
    }
  }
}

// Azure Monitor Windows Agent Extension
resource azureMonitorAgentExtension 'Microsoft.Compute/virtualMachines/extensions@2023-07-01' = {
  parent: virtualMachine
  name: 'AzureMonitorWindowsAgent'
  location: location
  dependsOn: [
    mmaExtension
  ]
  properties: {
    publisher: 'Microsoft.Azure.Monitor'
    type: 'AzureMonitorWindowsAgent'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
    enableAutomaticUpgrade: true
  }
}

// Network Watcher Agent Extension
resource networkWatcherExtension 'Microsoft.Compute/virtualMachines/extensions@2023-07-01' = {
  parent: virtualMachine
  name: 'NetworkWatcherAgent'
  location: location
  dependsOn: [
    azureMonitorAgentExtension
  ]
  properties: {
    publisher: 'Microsoft.Azure.NetworkWatcher'
    type: 'NetworkWatcherAgentWindows'
    typeHandlerVersion: '1.4'
    autoUpgradeMinorVersion: true
  }
}


// Outputs
@description('Data disk resource ID')
output dataManagedDiskResId string = virtualMachine.properties.storageProfile.dataDisks[0].managedDisk.id

@description('Data disk type')
output dataDiskType string = dataDiskType

@description('OS disk resource ID')
output osManagedDiskResId string = virtualMachine.properties.storageProfile.osDisk.managedDisk.id

@description('OS disk type')
output osDiskType string = osDiskType

@description('VM resource ID')
output vmResourceId string = virtualMachine.id
