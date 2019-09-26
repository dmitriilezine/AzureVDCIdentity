 param 
   ( 
        [Parameter(Mandatory)]
        [String]$SSLVaultName,   # this is Secrets Key Vault created in prior steps

	    [Parameter(Mandatory)]
        [String]$secretName,  # name of the secret that will be created in Key Vault and hold the PFX data
        
        [Parameter(Mandatory)]
        [String]$certPassword,  # PFX file password

        [Parameter(Mandatory)]
        [String]$PFXfileName     # name of the PFX file 

    ) 


# Read and covert PFX into secret for Key Vault
$fileContentBytes = Get-Content -Path $PFXfileName -Encoding Byte -ReadCount 0 
$fileContentEncoded = [System.Convert]::ToBase64String($fileContentBytes)

$jsonObject = @"
{
  "data": "$fileContentEncoded",
  "dataType" :"pfx",
  "password": "$certPassword"
}
"@

$jsonObjectBytes = [System.Text.Encoding]::UTF8.GetBytes($jsonObject)
$jsonEncoded = [System.Convert]::ToBase64String($jsonObjectBytes)

# Push secret to Key vault
$secret = ConvertTo-SecureString -String $jsonEncoded -AsPlainText –Force
Set-AzureKeyVaultSecret -VaultName $SSLVaultName -Name $secretName -SecretValue $secret 