// Azure Site Recovery Demo - Main Bicep Template
// This template deploys the complete Azure Site Recovery demo infrastructure including:
// - Resource groups in primary and secondary regions
// - Log Analytics workspace
// - Recovery Services vault with replication policies
// - Primary infrastructure (VMs, networking, replication components)

targetScope = 'subscription'

@description('The primary region to deploy resources.')
@allowed([
  'centralus'
  'eastus'
  'eastus2'
  'southcentralus'
  'westus2'
])
param primeLocation string

@description('The secondary region region to deploy resources to. This should be the paired region of the primary region to support the cross region restore functionality')
@allowed([
  'centralus'
  'eastus'
  'eastus2'
  'southcentralus'
  'westus2'
])
param secLocation string

@description('Administrator name for VMs that are created')
param vmAdminUsername string

@description('Password for the VMs that are created')
@secure()
param vmAdminPassword string

@description('The tags that wil be associated to the resources')
param tags object = {
  environment: 'tdd-asr-demo'
  'SecurityControl': 'Ignore'
}

@description('Creates a new GUID to create uniqueness for resources')
param uniqueData string

// Variables for resource naming and deployment references
var ASRVaultRGName = 'ASR-Vault-RG'
var ASRPrimWkldRGName = 'ASR-PrimWkld-RG'
var ASRSecWkldRGName = 'ASR-SecWkld-RG'

// Deploy resource groups
resource ASRVaultRG 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: ASRVaultRGName
  location: secLocation
  tags: tags
}

resource ASRPrimWkldRG 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: ASRPrimWkldRGName
  location: primeLocation
  tags: tags
}

resource ASRSecWkldRG 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: ASRSecWkldRGName
  location: secLocation
  tags: tags
}

// Deploy Log Analytics workspace
module laworkspace './loganalyticswspace.bicep' = {
  name: 'loganalyticswspace'
  scope: ASRPrimWkldRG
  params: {
    tags: tags
    //uniqueData: uniqueData
  }
}

// Deploy Recovery Services vault
module rsVaultModule './asrvault.bicep' = {
  name: 'deploy-rs-vault'
  scope: ASRVaultRG
  params: {
    loganwspace: laworkspace.outputs.logAnalyticsResourceId
    primeLocation: primeLocation
    secLocation: secLocation
    tags: tags
    uniqueData: uniqueData
  }
}

// Deploy replication policies
module rsVaultReplPoliciesModule './asrreplpolicies.bicep' = {
  name: 'deploy-rs-replication-policies'
  scope: ASRVaultRG
  params: {
    recSvcVaultName: rsVaultModule.outputs.asrvaultName
    //uniqueData: uniqueData
  }
}

// Deploy infrastructure resources
module infraModule './maininfra.bicep' = {
  name: 'maininfra'
  scope: ASRPrimWkldRG
  params: {
    loganwspace: laworkspace.outputs.logAnalyticsResourceId
    primeLocation: primeLocation
    frontendreplpol: rsVaultReplPoliciesModule.outputs.cstRepPolFeResId
    backendreplpol: rsVaultReplPoliciesModule.outputs.cstRepPolBeResId
    asrvaultName: rsVaultModule.outputs.asrvaultName
    asrvaultRG: ASRVaultRGName
    storageAccountCacheResId: rsVaultModule.outputs.storageAccountCacheResId
    secLocation: secLocation
    secResourceGroupName: ASRSecWkldRGName
    tags: tags
    vmAdminPassword: vmAdminPassword
    vmAdminUsername: vmAdminUsername
  }
}
