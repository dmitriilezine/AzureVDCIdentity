# AzureVDCIdentity
Deployment of ADDS/ADCS/ADFS/WAP/AADC in Azure VDC. 

ADDS deloyment can deploy new ADDS forest or join existing forest. 
It can be deployed with AD DNS or with external DNS that supports dynamic updates.

## Shared Services Requirements
There are number of services that are required to be present for this deployment to work - 
 - vNet must be present with specfic subnets and NSGs. 
	- Sample deployment for network is provided in "Network" module
 - Diagnostics storage account must be present.
	- Sample template is provided in "Logging" module
 - Log Analytics workspace must be present.
	- Sample template is provided in "Logging" module
 - Secrets Key Vault must be present with passwords for accounts used for/by ADDS deployment and ADFS certificate
.
