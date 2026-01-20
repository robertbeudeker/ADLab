Configuration AddDomain {
param (
    [Parameter(Mandatory = $true)]
    [String]$dnsSuffix,

    [Parameter(Mandatory = $true)]
    [String]$netbiosName,

    [Parameter(Mandatory = $true)]
    [String]$netbiosNameParent,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullorEmpty()]
    [System.Management.Automation.PSCredential]
    $Credential
)
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName ComputerManagementDsc -ModuleVersion "10.0.0"
    Import-DscResource -ModuleName ActiveDirectoryDsc -ModuleVersion "6.7.1"
    [System.Management.Automation.PSCredential]$ParentDomainCreds = New-Object System.Management.Automation.PSCredential ("$($Credential.UserName)@$netbiosNameParent.$dnsSuffix", $Credential.Password)

    Node localhost
    {
        LocalConfigurationManager
        {
            #ActionAfterReboot = 'ContinueConfiguration'
            #ConfigurationMode = 'ApplyOnly'
            RebootNodeIfNeeded = $true
        }

        WindowsFeature ADDSInstall
        {
            Ensure = "Present"
            Name = "AD-Domain-Services"
        }

        WindowsFeature RSAT
        {
            Ensure = "Present"
            Name = "RSAT"
            DependsOn = "[WindowsFeature]ADDSInstall"
        }

        #PendingReboot BeforeADInstall 
        #{ 
        #    Name = "BeforeADInstall" 
        #    DependsOn = "[WindowsFeature]ADDSInstall"
        #}

        ADDomain ChildDomain
        {
            DomainName                    = "$netbiosName.$dnsSuffix"
            DomainNetbiosName             = $netbiosName
            ParentDomainName              = "$netbiosNameParent.$dnsSuffix"
            Credential                    = $ParentDomainCreds
            SafeModeAdministratorPassword = $Credential
            DomainType                    = 'TreeDomain'
            DependsOn = "[WindowsFeature]ADDSInstall"
        }

        PendingReboot Reboot1
        { 
            Name = "RebootServer" 
            DependsOn = "[ADDomain]ChildDomain"
        }


        #Script ADDomainToForest
        #{
        #    GetScript = {
        #        $isDC = (Get-CimInstance Win32_ComputerSystem).DomainRole -ge 4
        #        return @{ 'Result'= "$isDC"}
        #    }
        #    SetScript = {
        #        Import-Module ADDSDeployment
        #        Install-ADDSDomain -CreateDnsDelegation:$false `
        #        -Credential $using:ParentDomainCreds `
        #        -NewDomainName "$using:netbiosName.$using:dnsSuffix" `
        #        -ParentDomainName "$using:netbiosNameParent.$using:dnsSuffix" `
        #        -InstallDns:$false `
        #        -DomainMode WinThreshold `
        #        -DomainType TreeDomain `
        #        -NewDomainNetbiosName $using:netbiosName `
        #        -DatabasePath "C:\Windows\NTDS" `
        #        -LogPath "C:\Windows\NTDS" `
        #        -SysvolPath "C:\Windows\SYSVOL" `
        #        -NoRebootOnCompletion:$true `
        #        -SafeModeAdministratorPassword $using:Credential.Password `
        #        -Force:$true
        #    }
        #    TestScript = { (Get-CimInstance Win32_ComputerSystem).DomainRole -ge 4 }
        #    DependsOn = "[PendingReboot]BeforeADInstall"
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
        #    DependsOn = "[Script]ADDomainToForest"
        #}
        #PendingReboot AfterADInstall
        #{
        #    Name      = 'AfterADInstall'
        #    DependsOn = '[Script]Reboot'
        #}
    }
}