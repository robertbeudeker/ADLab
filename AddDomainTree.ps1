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