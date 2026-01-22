param location string = resourceGroup().location
@description('Administrator username used for the default domain administrator and member servers')
param adminUsername string = 'adlabadmin'
@description('Password to be used voor default domain administrator and member servers local admin password')
@secure()
param adminPassword string
@description('FQDN suffix for the domain, for example adlab.local')
param dnsSuffix string = 'adlab.local'
@description('Active Directory Forest Netbios name')
param netbiosName string
@description('Active Directory TreeDomain Netbios name')
param childNetbiosName string
@description('Azure virtual network name, for example adlab-vnet')
param vnetName string

@description('definition for all servers.')
var computers = {
  DNS: {
    name: 'SR01'
    ip: '10.10.10.10'
  }
  DC1 : {
    name: 'SR02'
    ip: '10.10.10.12'
  }
  DC2 : {
    name: 'SR03'
    ip: '10.10.10.13'
  }
  DC3 : {
    name: 'SR04'
    ip: '10.10.10.14'
  }
  DC4 : {
    name: 'SR05'
    ip: '10.10.10.15'
  }
  MB1: {
    name: 'SR06'
    ip: '10.10.10.16'
  }
}

var vnetPrefixes= ['10.10.0.0/16']
var ADsubnet = '10.10.10.0/24'
var bastionSubnet = '10.10.224.0/24'

module nsgAD 'br/public:avm/res/network/network-security-group:0.5.2' = {
  name: 'ad-subnet-nsg-deployment'
  params: {
    name: 'ad-subnet-nsg'
  }
}

var networks = {
  addressPrefixes : vnetPrefixes
  subnets : [
      {
        name: 'AD'
        properties: {
          addressPrefix: ADsubnet
          networkSecurityGroup: {
            id: nsgAD.outputs.resourceId
          } 
        }
      }
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: bastionSubnet
        }
    }
  ]
}

resource vnet 'Microsoft.Network/virtualNetworks@2025-01-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: networks.addressPrefixes
    }
    subnets: networks.subnets
  }
}

resource ADsubnetObj 'Microsoft.Network/virtualNetworks/subnets@2025-01-01' existing = {
  name: 'AD'
  parent: vnet
}

module bastion 'br/public:avm/res/network/bastion-host:0.8.2' = {
  name: 'bastion-deployment'
  params: {
    name: 'bastion'
    virtualNetworkResourceId: vnet.id
    skuName: 'Developer'
  }
}

module dnsServer 'br/public:avm/res/compute/virtual-machine:0.21.0' = {
  name: '${computers.DNS.name}-deployment'
  params: {
    name: computers.DNS.name
    availabilityZone: -1
    nicConfigurations: [
      {
        ipConfigurations: [
          {
            name: 'ipconfig01'
            subnetResourceId: ADsubnetObj.id
            privateIPAllocationMethod: 'Static'
            privateIPAddress: computers.DNS.ip
          }
        ]
        nicSuffix: '-nic'
        enableAcceleratedNetworking: false
      }
    ]
    osDisk: {
      managedDisk: {
        storageAccountType: 'StandardSSD_LRS'
      }
    }
    osType: 'Windows'
    vmSize: 'Standard_B1ms'
    adminUsername: adminUsername
    adminPassword: adminPassword
    imageReference: {
      offer: 'WindowsServer'
      publisher: 'MicrosoftWindowsServer'
      sku: '2025-datacenter-azure-edition'
      version: 'latest'
    }
    tags: {
      role: 'DNS'
    }
  }
}

resource dnsServerobj 'Microsoft.Compute/virtualMachines@2025-04-01' existing = {
  name: computers.DNS.name
  dependsOn: [
    dnsServer
  ]
}

resource DNSServerConfig 'Microsoft.Compute/virtualMachines/extensions@2022-08-01' = {
  parent: dnsServerobj
  name: 'DNSserverInitialConfig-deployment'
  location: location
  properties: {
    publisher: 'Microsoft.Powershell'
    type: 'DSC'
    typeHandlerVersion: '2.83'
    autoUpgradeMinorVersion: true
    settings: {
      ModulesUrl: 'https://github.com/robertbeudeker/ADLab/raw/refs/heads/main/DSC/DNS.ps1.zip'
      ConfigurationFunction: 'DNS.ps1\\DNS'
      Properties: {
        DomainName: dnsSuffix
        NetbiosName: netbiosName
        NetbiosNameChild: childNetbiosName
      }
    }
  }
}

module vnetdns 'mod_vnetDNS.bicep' = {
  name: 'vnetSetDNSserver-deployment'
  params: {
    dnsServers: [computers.DNS.ip]
    addressPrefixes: networks.addressPrefixes
    vnetName: vnetName
    location: location
  }
  dependsOn: [
    DNSServerConfig
  ]
}

resource dnsconfig 'Microsoft.Compute/virtualMachines/runCommands@2025-04-01' = {
  name: 'DNSServerAdditionalConfiguation-deployment'
  dependsOn: [DNSServerConfig]
  parent: dnsServerobj
  location: location
  properties: {
    source: {
      script: '''
          param (
            [string]$dnsSuffix,
            [string]$netbiosName,
            [String]$NetbiosNameChild,
            [string]$IP,
            [string]$serverName
          )
          Add-DnsServerResourceRecordA -name $serverName -zonename $dnsSuffix -IPv4Address $IP
          $oldObj=Get-DnsServerResourceRecord -ZoneName "$netbiosName.$dnsSuffix" -RRType SOA
          $newObj = [ciminstance]::new($oldObj)
          $newObj.RecordData.PrimaryServer = "$serverName.$dnsSuffix"
          Set-DnsServerResourceRecord -NewInputObject $newObj -OldInputObject $oldObj -ZoneName "$netbiosName.$dnsSuffix"
          $oldObj=Get-DnsServerResourceRecord -ZoneName "$NetbiosNameChild.$dnsSuffix" -RRType SOA
          $newObj = [ciminstance]::new($oldObj)
          $newObj.RecordData.PrimaryServer = "$serverName.$dnsSuffix"
          Set-DnsServerResourceRecord -NewInputObject $newObj -OldInputObject $oldObj -ZoneName "$NetbiosNameChild.$dnsSuffix"
        '''
    }
    parameters: [
      {
        name: 'dnsSuffix'
        value: dnsSuffix
      }
      {
        name: 'netbiosName'
        value: netbiosName
      }
      {
        name: 'NetbiosNameChild'
        value: childNetbiosName
      }
      {
        name: 'IP'
        value: computers.DNS.ip
      }
      {
        name: 'serverName'
        value: computers.DNS.name
      }
    ]
  }
}

module ADServer1 'br/public:avm/res/compute/virtual-machine:0.21.0' = {
  name: '${computers.DC1.name}-deployment'
  dependsOn: [vnetdns]
  params: {
    name: computers.DC1.name
    availabilityZone: -1
    managedIdentities: {
      systemAssigned: true
    }
    nicConfigurations: [
      {
        ipConfigurations: [
          {
            name: 'ipconfig01'
            subnetResourceId: ADsubnetObj.id
            privateIPAllocationMethod: 'Static'
            privateIPAddress: computers.DC1.ip
          }
        ]
        nicSuffix: '-nic'
        enableAcceleratedNetworking: false
      }
    ]
    osDisk: {
      managedDisk: {
        storageAccountType: 'StandardSSD_LRS'
      }
    }
    osType: 'Windows'
    vmSize: 'Standard_B2ms'
    adminUsername: adminUsername
    adminPassword: adminPassword
    imageReference: {
      offer: 'WindowsServer'
      publisher: 'MicrosoftWindowsServer'
      sku: '2025-datacenter-azure-edition'
      version: 'latest'
    }
    extensionGuestConfigurationExtension: {
      enabled: false
    }
    tags: {
      role: 'AD'
    }
  }
}

resource ADServer1Obj 'Microsoft.Compute/virtualMachines@2025-04-01' existing = {
  name: computers.DC1.name
  dependsOn: [
    ADServer1
  ]
}

resource createADForest 'Microsoft.Compute/virtualMachines/extensions@2022-08-01' = {
  parent: ADServer1Obj
  dependsOn: [dnsconfig]
  name: 'CreateADForestFirstDC'
  location: location
  properties: {
    publisher: 'Microsoft.Powershell'
    type: 'DSC'
    typeHandlerVersion: '2.83'
    autoUpgradeMinorVersion: true
    settings: {
      ModulesUrl: 'https://github.com/robertbeudeker/ADLab/raw/refs/heads/main/DSC/CreateNewADForest.ps1.zip'
      ConfigurationFunction: 'CreateNewADForest.ps1\\CreateNewADForest'
      Properties: {
        dnsSuffix: dnsSuffix
        NetbiosName: netbiosName
        Credential: {
          UserName: adminUsername
          Password: 'PrivateSettingsRef:AdminPassword'
        }
      }
    }
    protectedSettings: {
      Items: {
        AdminPassword: adminPassword
      }
    }
  }
}

module ADServer2 'br/public:avm/res/compute/virtual-machine:0.21.0' = {
  name: '${computers.DC2.name}-deployment'
  dependsOn: [vnetdns]
  params: {
    name: computers.DC2.name
    availabilityZone: -1
    managedIdentities: {
      systemAssigned: true
    }
    nicConfigurations: [
      {
        ipConfigurations: [
          {
            name: 'ipconfig01'
            subnetResourceId: ADsubnetObj.id
            privateIPAllocationMethod: 'Static'
            privateIPAddress: computers.DC2.ip
          }
        ]
        nicSuffix: '-nic'
        enableAcceleratedNetworking: false
      }
    ]
    osDisk: {
      managedDisk: {
        storageAccountType: 'StandardSSD_LRS'
      }
    }
    osType: 'Windows'
    vmSize: 'Standard_B2ms'
    adminUsername: adminUsername
    adminPassword: adminPassword
    imageReference: {
      offer: 'WindowsServer'
      publisher: 'MicrosoftWindowsServer'
      sku: '2025-datacenter-azure-edition'
      version: 'latest'
    }
    extensionGuestConfigurationExtension: {
      enabled: false
    }
    tags: {
      role: 'AD'
    }
  }
}

resource ADServer2Obj 'Microsoft.Compute/virtualMachines@2025-04-01' existing = {
  name: computers.DC2.name
  dependsOn: [
    ADServer2
    vnetdns
  ]
}

resource AddDC 'Microsoft.Compute/virtualMachines/extensions@2022-08-01' = {
  parent: ADServer2Obj
  name: 'AddSecondDCToForest'
  dependsOn: [
    createADForest
  ]
  location: location
  properties: {
    publisher: 'Microsoft.Powershell'
    type: 'DSC'
    typeHandlerVersion: '2.83'
    autoUpgradeMinorVersion: true
    settings: {
      ModulesUrl: 'https://github.com/robertbeudeker/ADLab/raw/refs/heads/main/DSC/AddDomainController.ps1.zip'
      ConfigurationFunction: 'AddDomainController.ps1\\AddDomainController'
      Properties: {
        dnsSuffix: dnsSuffix
        netbiosName : netbiosName
        Credential: {
          UserName: adminUsername
          Password: 'PrivateSettingsRef:AdminPassword'
        }
      }
    }
    protectedSettings: {
      Items: {
        AdminPassword: adminPassword
      }
    }
  }
}

module ADServer3 'br/public:avm/res/compute/virtual-machine:0.21.0' = {
  name: '${computers.DC3.name}-deployment'
  dependsOn: [vnetdns]
  params: {
    name: computers.DC3.name
    availabilityZone: -1
    managedIdentities: {
      systemAssigned: true
    }
    nicConfigurations: [
      {
        ipConfigurations: [
          {
            name: 'ipconfig01'
            subnetResourceId: ADsubnetObj.id
            privateIPAllocationMethod: 'Static'
            privateIPAddress: computers.DC3.ip
          }
        ]
        nicSuffix: '-nic'
        enableAcceleratedNetworking: false
      }
    ]
    osDisk: {
      managedDisk: {
        storageAccountType: 'StandardSSD_LRS'
      }
    }
    osType: 'Windows'
    vmSize: 'Standard_B2ms'
    adminUsername: adminUsername
    adminPassword: adminPassword
    imageReference: {
      offer: 'WindowsServer'
      publisher: 'MicrosoftWindowsServer'
      sku: '2025-datacenter-azure-edition'
      version: 'latest'
    }
    extensionGuestConfigurationExtension: {
      enabled: false
    }
    tags: {
      role: 'AD'
      Domain: childNetbiosName
    }
  }
}

resource ADServer3Obj 'Microsoft.Compute/virtualMachines@2025-04-01' existing = {
  name: computers.DC3.name
  dependsOn: [
    ADServer3
    vnetdns
  ]
}

resource AddChildDomain 'Microsoft.Compute/virtualMachines/extensions@2022-08-01' = {
  parent: ADServer3Obj
  name: 'InstallADWait'
  dependsOn: [
    ADServer3Obj
  ]
  location: location
  properties: {
    publisher: 'Microsoft.Powershell'
    type: 'DSC'
    typeHandlerVersion: '2.83'
    autoUpgradeMinorVersion: true
    settings: {
      ModulesUrl: 'https://github.com/robertbeudeker/ADLab/raw/refs/heads/main/DSC/installADWait.ps1.zip'
      ConfigurationFunction: 'InstallADWait.ps1\\InstallADWait'
      Properties: {
        dnsSuffix: dnsSuffix
        netbiosName : netbiosName
        Credential: {
          UserName: adminUsername
          Password: 'PrivateSettingsRef:AdminPassword'
        }
      }
    }
    protectedSettings: {
      Items: {
        AdminPassword: adminPassword
      }
    }
  }
}

resource CreateTreeDomain 'Microsoft.Compute/virtualMachines/runCommands@2025-04-01' = {
  name: 'CreateTreeDomain'
  dependsOn: [AddChildDomain]
  parent: ADServer3Obj
  location: location
  properties: {
    source: {
      script: '''
        param (
          [Parameter(Mandatory = $true)]
          [string]$dnsSuffix,
          [Parameter(Mandatory = $true)]
          [string]$netbiosName,
          [Parameter(Mandatory = $true)]
          [String]$netbiosNameParent,
          [Parameter(Mandatory = $true)]
          [String]$adminuser,
          [Parameter(Mandatory = $true)]
          [String]$adminpassword
        )
        $secAdminpassword = ConvertTo-SecureString $adminpassword -AsPlainText -Force
        $user = "$adminuser@$netbiosNameParent.$dnsSuffix"
        write-host $user
        $cred = New-Object System.Management.Automation.PSCredential ($user, $secAdminpassword)
        Import-Module ADDSDeployment
        Install-ADDSDomain `
          -NewDomainName "$netbiosName.$dnsSuffix" `
          -ParentDomainName "$netbiosNameParent.$dnsSuffix" `
          -Credential $cred `
          -SafeModeAdministratorPassword $secAdminpassword `
          -DomainType TreeDomain `
          -InstallDns:$false `
          -CreateDnsDelegation:$false `
          -DatabasePath "C:\Windows\NTDS" `
          -LogPath "C:\Windows\NTDS" `
          -SysvolPath "C:\Windows\SYSVOL" `
          -NoRebootOnCompletion:$false `
          -Force:$true
        '''
    }
    parameters: [
      {
        name: 'dnsSuffix'
        value: dnsSuffix
      }
      {
        name: 'netbiosName'
        value: childNetbiosName
      }
      {
        name: 'netbiosNameParent'
        value: netbiosName
      }
      {
        name: 'adminuser'
        value: adminUsername
      }
    ]
    protectedParameters: [
      {
        name: 'adminpassword'
        value: adminPassword
      }
    ]
  }
}

module ADServer4 'br/public:avm/res/compute/virtual-machine:0.21.0' = {
  name: '${computers.DC4.name}-deployment'
  dependsOn: [vnetdns]
  params: {
    name: computers.DC4.name
    availabilityZone: -1
    managedIdentities: {
      systemAssigned: true
    }
    nicConfigurations: [
      {
        ipConfigurations: [
          {
            name: 'ipconfig01'
            subnetResourceId: ADsubnetObj.id
            privateIPAllocationMethod: 'Static'
            privateIPAddress: computers.DC4.ip
          }
        ]
        nicSuffix: '-nic'
        enableAcceleratedNetworking: false
      }
    ]
    osDisk: {
      managedDisk: {
        storageAccountType: 'StandardSSD_LRS'
      }
    }
    osType: 'Windows'
    vmSize: 'Standard_B2ms'
    adminUsername: adminUsername
    adminPassword: adminPassword
    imageReference: {
      offer: 'WindowsServer'
      publisher: 'MicrosoftWindowsServer'
      sku: '2025-datacenter-azure-edition'
      version: 'latest'
    }
    extensionGuestConfigurationExtension: {
      enabled: false
    }
    tags: {
      role: 'AD'
      Domain: childNetbiosName
    }
  }
}

resource ADServer4Obj 'Microsoft.Compute/virtualMachines@2025-04-01' existing = {
  name: computers.DC4.name
  dependsOn: [
    ADServer4
    vnetdns
  ]
}

resource AddDCChildDomain 'Microsoft.Compute/virtualMachines/extensions@2022-08-01' = {
  parent: ADServer4Obj
  name: 'AddSecondDCToFChildDomain'
  dependsOn: [
    CreateTreeDomain
  ]
  location: location
  properties: {
    publisher: 'Microsoft.Powershell'
    type: 'DSC'
    typeHandlerVersion: '2.83'
    autoUpgradeMinorVersion: true
    settings: {
      ModulesUrl: 'https://github.com/robertbeudeker/ADLab/raw/refs/heads/main/DSC/AddDomainController.ps1.zip'
      ConfigurationFunction: 'AddDomainController.ps1\\AddDomainController'
      Properties: {
        dnsSuffix: dnsSuffix
        netbiosName : childNetbiosName
        Credential: {
          UserName: adminUsername
          Password: 'PrivateSettingsRef:AdminPassword'
        }
      }
    }
    protectedSettings: {
      Items: {
        AdminPassword: adminPassword
      }
    }
  }
}

module MemberServer1 'br/public:avm/res/compute/virtual-machine:0.21.0' = {
  name: '${computers.MB1.name}-deployment'
  dependsOn: [CreateTreeDomain]
  params: {
    name: computers.MB1.name
    availabilityZone: -1
    managedIdentities: {
      systemAssigned: true
    }
    nicConfigurations: [
      {
        ipConfigurations: [
          {
            name: 'ipconfig01'
            subnetResourceId: ADsubnetObj.id
            privateIPAllocationMethod: 'Static'
            privateIPAddress: computers.MB1.ip
          }
        ]
        nicSuffix: '-nic'
        enableAcceleratedNetworking: false
      }
    ]
    osDisk: {
      managedDisk: {
        storageAccountType: 'StandardSSD_LRS'
      }
    }
    osType: 'Windows'
    vmSize: 'Standard_B2ms'
    adminUsername: adminUsername
    adminPassword: adminPassword
    imageReference: {
      offer: 'WindowsServer'
      publisher: 'MicrosoftWindowsServer'
      sku: '2025-datacenter-azure-edition'
      version: 'latest'
    }
    extensionGuestConfigurationExtension: {
      enabled: false
    }
    tags: {
      role: 'EntraIDConnect'
    }
  }
}

resource MB1 'Microsoft.Compute/virtualMachines@2025-04-01' existing = {
  name: computers.MB1.name
  dependsOn: [MemberServer1]
}

resource joinDomain 'Microsoft.Compute/virtualMachines/extensions@2022-11-01' = {
  parent: MB1
  name: 'joindomain'
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'JsonADDomainExtension'
    typeHandlerVersion: '1.3'
    autoUpgradeMinorVersion: true
    settings: {
      name: '${childNetbiosName}.${dnsSuffix}'
      user: '${adminUsername}@${childNetbiosName}.${dnsSuffix}'
      restart: true
      options: 3
    }
    protectedSettings: {
      password: adminPassword
    }
  }
}

output adminusername string = adminUsername
output adminpassword string = adminPassword
