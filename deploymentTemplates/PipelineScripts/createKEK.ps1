
# Define parameters 

$prefix = 'usscdev1' #change this to the target region prefix and environment
$logonname = "dmitrii@contoso.com" #change to your AAD account in Tier 0 subscription
$location = "southcentralus" #change to the target region

#$rgName = $prefix+'-identity-kek-kv-rg'
$rgName = 'Tier0AKV'
$KeyVaultName = $prefix+'-ade-kek-kv'
$keyEncryptionKeyNameAADC = $prefix+'-aadc-kek'
$keyEncryptionKeyNameADDS = $prefix+'-adds-kek'
$keyEncryptionKeyNameADFS = $prefix+'-adfs-kek'
$keyEncryptionKeyNameWAP = $prefix+'-wap-kek'
$keyEncryptionKeyNameRDS = $prefix+'-rds-kek'

# Create Key Vault in Tier 0 subscription and grant access to keys
New-AzureRmKeyVault -VaultName $keyVaultName -ResourceGroupName $rgName -Sku Premium -EnabledForDiskEncryption -Location $location # <--- run in Dev --
# -- LAB or PROD --->>> New-AzureRmKeyVault -VaultName $keyVaultName -ResourceGroupName $rgName -Sku Premium -EnabledForDiskEncryption -EnableSoftDelete -EnablePurgeProtection -Location $location

Set-AzureRmKeyVaultAccessPolicy -VaultName $keyVaultName -UserPrincipalName $logonname -PermissionsToKeys decrypt,encrypt,unwrapKey,wrapKey,verify,sign,get,list,update,create,import,delete,backup,restore,recover,purge -PassThru

# Create 5 new keys in the key vault
Add-AzureKeyVaultKey -VaultName $KeyVaultName -Name $keyEncryptionKeyNameAADC -Destination 'Software'
Add-AzureKeyVaultKey -VaultName $KeyVaultName -Name $keyEncryptionKeyNameADDS -Destination 'Software'
Add-AzureKeyVaultKey -VaultName $KeyVaultName -Name $keyEncryptionKeyNameADFS -Destination 'Software'
Add-AzureKeyVaultKey -VaultName $KeyVaultName -Name $keyEncryptionKeyNameWAP -Destination 'Software'
Add-AzureKeyVaultKey -VaultName $KeyVaultName -Name $keyEncryptionKeyNameRDS -Destination 'Software'

# Get URL for each key
$keyEncryptionKeyUrlAADC = (Get-AzureKeyVaultKey -VaultName $KeyVaultName -Name $keyEncryptionKeyNameAADC).Key.kid
$keyEncryptionKeyUrlADDS = (Get-AzureKeyVaultKey -VaultName $KeyVaultName -Name $keyEncryptionKeyNameADDS).Key.kid
$keyEncryptionKeyUrlADFS = (Get-AzureKeyVaultKey -VaultName $KeyVaultName -Name $keyEncryptionKeyNameADFS).Key.kid
$keyEncryptionKeyUrlWAP = (Get-AzureKeyVaultKey -VaultName $KeyVaultName -Name $keyEncryptionKeyNameWAP).Key.kid
$keyEncryptionKeyUrlRDS = (Get-AzureKeyVaultKey -VaultName $KeyVaultName -Name $keyEncryptionKeyNameRDS).Key.kid

# Print URLs to screen. Copy/paste it and share with Identity pipeline team
$keyEncryptionKeyUrlAADC
$keyEncryptionKeyUrlADDS
$keyEncryptionKeyUrlADFS
$keyEncryptionKeyUrlWAP
$keyEncryptionKeyUrlRDS


