param dnsServers array
param addressPrefixes array
param vnetName string
param location string

resource vnetDNSserver 'Microsoft.Network/virtualNetworks@2025-01-01' = {
  name: vnetName
  location: location
  properties: {
    dhcpOptions: {
      dnsServers: dnsServers
    }
    addressSpace: {
      addressPrefixes: addressPrefixes
    }
  }
}
