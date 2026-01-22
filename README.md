# Deploy Active Directory Forest test lab to Azure.

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Frobertbeudeker%2FADLab%2Frefs%2Fheads%2Fmain%2Fmain.json)

This repository can be used to deploy an Active Directory environment in Azure.
The Active Directory structure consists of a Root Forest with a Tree domain as the “Working Domain.” This setup has been widely used and is a best practice from the past to keep the Enterprise Admin and Schema Admin roles out of the working domain.
DNS is hosted on a separate server and is not part of the Active Directory domain. In many large organizations, an alternative DNS product is used instead of Active Directory–integrated DNS.

The purpose of this repository is to quickly build an Active Directory lab environment. This lab can then be used, for example, for forest recovery testing, optionally in combination with Entra ID Connect.

*Deployment of Active Directory and Domain Controller promotion is performed using PowerShell Desired State Configuration (DSC) modules and Azure Run Command scripts. Unfortunately, the existing PowerShell DSC module ActiveDirectoryDSC does not support this specific scenario. For example, a new forest cannot be created without installing the DNS role on the Domain Controller, and creating a new tree domain in an existing forest results in an error.
To resolve this, a customized version of ActiveDirectoryDSC, modified by me, is bundled with the DSC scripts. The creation of the tree domain is performed using an Azure Run Command PowerShell script instead of the ActiveDirectoryDSC module.*