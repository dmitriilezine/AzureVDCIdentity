

# Create Folder
$scriptroot = "c:\AADCMSI"
New-Item -ItemType Directory $scriptroot

# Wait 120 seconds
Start-Sleep -Seconds 120

copy-item -path ".\scripts\AzureADConnect.msi" -destination $scriptroot -Confirm:$false
