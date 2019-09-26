used to deploy AKV for the following puposes:

- keyvault.json - AKV for ADE. Use in test environment. 
- keyvaultWithSecret.json - AKV for storing Certificate that will be used by ADFS and WAP VMs. Use in test environment.
- templates with soft delete should be used in production environment to protect AKVs from accidental deletion