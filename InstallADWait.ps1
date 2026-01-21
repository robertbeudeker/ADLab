Configuration InstallADWait {
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

        Script Reboot
        {
            TestScript = {
            return (Test-Path HKLM:\SOFTWARE\MyMainKey\RebootKey)
            }
            SetScript = {
                    New-Item -Path HKLM:\SOFTWARE\MyMainKey\RebootKey -Force
                    $global:DSCMachineStatus = 1 
                }
            GetScript = { return @{result = 'result'}}
            DependsOn = "[WindowsFeature]ADDSInstall"
        }
        PendingReboot AfterADInstall
        {
            Name      = 'AfterADInstall'
            DependsOn = '[Script]Reboot'
        }

        WaitForADDomain DscForestWait
        {
            DomainName = "$NetbiosName.$dnsSuffix"
            Credential = $DomainCreds
            DependsOn = "[PendingReboot]AfterADInstall"
            RestartCount = 5
        }
    }
}