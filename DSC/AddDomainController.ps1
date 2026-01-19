Configuration AddDomainController {
param (
    [Parameter(Mandatory = $true)]
    [String]$dnsSuffix,

    [Parameter(Mandatory = $true)]
    [String]$netbiosName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullorEmpty()]
    [System.Management.Automation.PSCredential]
    $Credential
)
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName ComputerManagementDsc -ModuleVersion "10.0.0"
    Import-DscResource -ModuleName ActiveDirectoryDsc -ModuleVersion "6.7.1"
    [System.Management.Automation.PSCredential]$DomainCreds = New-Object System.Management.Automation.PSCredential ("$netbiosName\$($Credential.UserName)", $Credential.Password)

    Node localhost
    {
        LocalConfigurationManager
        {
            ActionAfterReboot = 'ContinueConfiguration'
            ConfigurationMode = 'ApplyOnly'
            RebootNodeIfNeeded = $true
        }

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

        PendingReboot BeforeADInstall 
        { 
            Name = "BeforeADInstall" 
            DependsOn = "[WindowsFeature]ADDSInstall"
        }

        WaitForADDomain DscForestWait
        {
            DomainName = "$NetbiosName.$dnsSuffix"
            Credential = $Credential
            DependsOn = "[PendingReboot]BeforeADInstall"
        }

        ADDomainController AddDomainController
        {
            DomainName = "$NetbiosName.$dnsSuffix"
            Credential = $DomainCreds
            SafemodeAdministratorPassword = $Credential
            DependsOn = "[WaitForADDomain]DscForestWait"
        }

        PendingReboot AfterADInstall 
        { 
            Name = "AfterADInstall" 
            DependsOn = "[ADDomainController]AddDomainController"
        }
    }
}