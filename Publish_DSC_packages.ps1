Publish-AzVMDscConfiguration -ConfigurationPath .\AddDomain.ps1 -OutputArchivePath .\DSC\AddDomain.ps1.zip -Force
Publish-AzVMDscConfiguration -ConfigurationPath .\CreateNewADForest.ps1 -OutputArchivePath .\DSC\CreateNewADForest.ps1.zip -Force
Publish-AzVMDscConfiguration -ConfigurationPath .\InstallADWait.ps1 -OutputArchivePath .\DSC\installADWait.ps1.zip -Force
Publish-AzVMDscConfiguration -ConfigurationPath .\DNS.ps1 -OutputArchivePath .\DSC\DNS.ps1.zip -Force
Publish-AzVMDscConfiguration -ConfigurationPath .\AddDomainController.ps1 -OutputArchivePath .\DSC\AddDomainController.ps1.zip -Force