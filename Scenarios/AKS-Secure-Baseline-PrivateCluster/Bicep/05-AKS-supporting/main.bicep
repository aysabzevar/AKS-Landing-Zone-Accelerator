targetScope = 'subscription'

param rgName string
param vnetName string
param subnetName string
param privateDNSZoneACRName string = 'privatelink${environment().suffixes.acrLoginServer}'
param privateDNSZoneKVName string = 'privatelink.vaultcore.azure.net'
param privateDNSZoneSAName string = 'privatelink.file.${environment().suffixes.storage}'
param acrName string = 'eslzacr${uniqueString('acrvws', uniqueString(subscription().id, utcNow()))}'
param keyvaultName string = 'eslz-kv-${uniqueString('acrvws', uniqueString(subscription().id, utcNow()))}'
param storageAccountName string = 'eslzsa${uniqueString('aks', uniqueString(subscription().id), utcNow())}'
param storageAccountType string
param location string = deployment().location

resource servicesSubnet 'Microsoft.Network/virtualNetworks/subnets@2021-02-01' existing = {
  scope: resourceGroup(rg.name)
  name: '${vnetName}/${subnetName}'
}

resource privateDNSZoneSA 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  scope: resourceGroup(rg.name)
  name: privateDNSZoneSAName
}

resource privateDNSZoneKV 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  scope: resourceGroup(rg.name)
  name: privateDNSZoneKVName
}

resource privateDNSZoneACR 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  scope: resourceGroup(rg.name)
  name: privateDNSZoneACRName
}

module rg 'br/public:avm/res/resources/resource-group:0.4.0' = {
  name: rgName
  params: {
    name: rgName
    location: location
    enableTelemetry: true
  }
}

module registry 'br/public:avm/res/container-registry/registry:0.6.0' = {
  scope: resourceGroup(rg.name)
  name: acrName
  params: {
    name: acrName
    location: location
    acrAdminUserEnabled: true
    publicNetworkAccess: 'Disabled'
    acrSku: 'Premium'
    privateEndpoints: [
      {
        privateDnsZoneResourceIds: [
          privateDNSZoneACR.id
        ]
        subnetResourceId: servicesSubnet.id
      }
    ]
  }
}

module vault 'br/public:avm/res/key-vault/vault:0.11.0' = {
  scope: resourceGroup(rg.name)
  name: keyvaultName
  params: {
    name: keyvaultName
    enablePurgeProtection: true
    location: location
    sku: 'standard'
    enableVaultForDiskEncryption: true
    softDeleteRetentionInDays: 7
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
    }
    privateEndpoints: [
      {
        privateDnsZoneResourceIds: [
          privateDNSZoneKV.id
        ]
        subnetResourceId: servicesSubnet.id
      }
    ]
  }
}

module storageAccount 'br/public:avm/res/storage/storage-account:0.14.3' = {
  scope: resourceGroup(rg.name)
  name: storageAccountName
  params: {
    name: storageAccountName
    allowBlobPublicAccess: false
    location: location
    skuName: storageAccountType
    kind: 'StorageV2'
    privateEndpoints: [
      {
        privateDnsZoneResourceIds: [
          privateDNSZoneSA.id
        ]
        service: 'file'
        subnetResourceId: servicesSubnet.id
      }
    ]
  }
}

output acrName string = registry.outputs.name
output keyVaultName string = vault.outputs.name
