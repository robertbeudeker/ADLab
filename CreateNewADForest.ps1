Configuration CreateNewADForest {
param (
    [Parameter(Mandatory = $true)]
    [String]$dnsSuffix,

    [Parameter(Mandatory = $true)]
    [String]$NetbiosName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullorEmpty()]
    [System.Management.Automation.PSCredential]
    $Credential
)
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    #Import-DscResource -ModuleName ComputerManagementDsc -ModuleVersion "10.0.0"
    Import-DscResource -ModuleName ActiveDirectoryDsc -ModuleVersion "6.7.1"

    Node localhost
    {
        #LocalConfigurationManager
        #{
        #    ActionAfterReboot = 'ContinueConfiguration'
        #    ConfigurationMode = 'ApplyOnly'
        #    RebootNodeIfNeeded = $true
        #}

        WindowsFeature RSAT
        {
            Ensure = "Present"
            Name = "RSAT"
        }

        WindowsFeature ADDSInstall
        {
            Ensure = "Present"
            Name = "AD-Domain-Services"
        }

        ADDomain Forest
        {
            DomainName                    = "$netbiosName.$dnsSuffix"
            DomainNetbiosName             = $netbiosName
            Credential                    = $Credential 
            SafeModeAdministratorPassword = $Credential.Password
            ForestMode                    = 'WinThreshold'
            DependsOn = "[WindowsFeature]ADDSInstall"
        }

        #Script CreateNewADForest
        #{
        #    GetScript = {
        #        $isDC = (Get-CimInstance Win32_ComputerSystem).DomainRole -ge 4
        #        return @{ 'Result'= "$isDC"}
        #    }
        #    SetScript = {
        #        Import-Module ADDSDeployment
        #        Install-ADDSForest -CreateDnsDelegation:$false `
        #        -DatabasePath "C:\Windows\NTDS" `
        #        -DomainMode WinThreshold `
        #        -DomainName "$using:NetbiosName.$using:dnsSuffix" `
        #        -DomainNetbiosName $using:NetbiosName `
        #        -ForestMode WinThreshold `
        #        -InstallDns:$false `
        #        -LogPath "C:\Windows\NTDS" `
        #        -NoRebootOnCompletion:$true `
        #        -SysvolPath "C:\Windows\SYSVOL" `
        #        -SafeModeAdministratorPassword $using:Credential.Password `
        #        -Force:$true
        #    }
        #    TestScript = { (Get-CimInstance Win32_ComputerSystem).DomainRole -ge 4 }
        #    DependsOn = "[WindowsFeature]ADDSInstall"
        #}

        #Script Reboot
        #{
        #    TestScript = {
        #    return (Test-Path HKLM:\SOFTWARE\MyMainKey\RebootKey)
        #    }
        #    SetScript = {
        #            New-Item -Path HKLM:\SOFTWARE\MyMainKey\RebootKey -Force
        #            $global:DSCMachineStatus = 1 
        #        }
        #    GetScript = { return @{result = 'result'}}
        #    DependsOn = "[Script]CreateNewADForest"
        #}

        #PendingReboot Reboot1 
        #{ 
        #    Name = "RebootServer" 
        #    DependsOn = "[Script]Reboot"
        #}

        #WaitForADDomain DscForestWait
        #{
        #    DomainName = "$NetbiosName.$dnsSuffix"
        #    Credential = $Credential
        #    DependsOn = "[PendingReboot]Reboot1"
        #}
    }
}