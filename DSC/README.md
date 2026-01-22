| File | Description | Specifics |
| ----------- | ----------- |----------- |
| AddDomain.ps1.zip | Not used because of a bug in ActiveDirectoryDSC module when creating Tree Domain |
| AddDomainController.ps1.zip | DSC configuration to Add an Domain Controller to existing domain | Waits for Domain to come available |
| CreateNewADForest.ps1.zip | Creates new Active Directory Forest | Custom ActiveDirectoryDSC fix to disable DNS role isnatll  |
| DNS.ps1.zip | Install DNS Role. Sets DNS forwarder to Azure DNS. Creates needed DNS zones | |
| installADWait.ps1.zip | Installes AD role | waits for Domain to come available |