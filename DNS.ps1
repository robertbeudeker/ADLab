Configuration DNS {
    param (
    [Parameter(Mandatory = $true)]
    [String]$DomainName,

    [Parameter(Mandatory = $true)]
    [String]$NetbiosName,

    [Parameter(Mandatory = $true)]
    [String]$NetbiosNameChild
    )
    Import-DscResource -Module DnsServerDsc
    Import-DscResource -Module NetworkingDsc

    Node localhost
    {
        DnsClientGlobalSetting ConfigureSuffixSearchListMultiple
        {
            IsSingleInstance = 'Yes'
            SuffixSearchList = ($DomainName, "$NetbiosName.$DomainName")
            UseDevolution    = $true
            DevolutionLevel  = 0
        }
        WindowsFeature InstallDNS
        {
            Ensure = 'Present'
            Name   = 'DNS'
        }
        WindowsFeature InstallDNSTools
        {
            Ensure = 'Present'
            Name   = 'RSAT-DNS-Server'
        }
        DnsServerForwarder 'SetForwarders'
        {
            IsSingleInstance = 'Yes'
            IPAddresses      = @('168.63.129.16')
            UseRootHint      = $false
        }
        DnsServerPrimaryZone 'RootZone'
        {
            Ensure        = 'Present'
            Name          = $DomainName
            ZoneFile      = "$DomainName.dns"
            DynamicUpdate = 'NonSecureAndSecure'
        }
        DnsServerPrimaryZone 'ChildZoneForest'
        {
            Ensure        = 'Present'
            Name          = "$NetbiosName.$DomainName"
            ZoneFile      = "$NetbiosName.$DomainName.dns"
            DynamicUpdate = 'NonSecureAndSecure'
        }
        DnsServerPrimaryZone 'ChildZoneChild'
        {
            Ensure        = 'Present'
            Name          = "$NetbiosNameChild.$DomainName"
            ZoneFile      = "$NetbiosNameChild.$DomainName.dns"
            DynamicUpdate = 'NonSecureAndSecure'
        }
    }
}