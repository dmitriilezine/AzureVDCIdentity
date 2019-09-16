# AzureVDCIdentity
Deployment of ADDS/ADCS/ADFS/WAP/AADC in Azure VDC. ADDS can deploy new Forest or join existing forest. 
Can be deployed with AD DNS or with external DNS that supports dynamic updates.

## Shared Services Requirements
There are number of services that are required to be present for this deployment to work - mainly vNet must be present with specfic subnets and NSGs. 
Sample deployment for network is provided in "Network" module.
