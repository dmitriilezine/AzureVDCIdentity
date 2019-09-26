CommonJson folder contains JSON ARM templates used by multiple modules.

Current common templates:
1. vmDiagnostics.json - configures windows VM with VM diagnostics. Stroage account must be present in the same region.
2. deployAntimalware.json - installs Microsoft Azure Antimalware agent on windows VM
3. encryptVM.json - encrypts windows VM. Key Vault enabled for ADE must be present in the same region as VM.
4. encryptVMkek.json -  encrypts windows VM with KEK. Key Vault enabled for ADE must be present in the same region as VM.
5. deployLA.json - configured LA on VM