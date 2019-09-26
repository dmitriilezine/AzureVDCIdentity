these are sample templates to deploy required services used by the ADDS/AADC/ADFS/WAP/AADC deployments

- diagstorage.json used to deploy storage account used for diagnostics with VMs. must be in the same region as VMs
- loganalytics.json used to deploy la workspace used with pretty all resources in this deployment. It can be deployed in the same subscription as VMs or
in different subscription, referered as Tier0 subscription.
- update management ps1 and json used to deploy automation account in LA that will be used to patch VMs