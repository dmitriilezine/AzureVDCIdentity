param (
    [string]$resourceGroup,
    [string]$prefix,
    [string]$location
)

# generate a random storage account name
$storageAccount = $prefix + -join ((97..122) | Get-Random -Count 13 | % {[char]$_})

# create the resource group
try
{
    Get-AzureRmResourceGroup -Name $resourceGroup
}
catch
{
    New-AzureRMResourceGroup -Name $resourceGroup -location $location
}

Start-Sleep -Seconds 30

# create the storage account / container
New-AzureRmStorageAccount -ResourceGroupName $resourceGroup -AccountName $storageAccount -Location $location -SkuName Standard_LRS

# get the key
$key = (Get-AzureRmStorageAccountKey -ResourceGroupName $resourceGroup -AccountName $storageAccount).Value[0]

# create the container
$sa = New-AzureStorageContext -StorageAccountName $storageAccount -StorageAccountKey $key
New-AzureStorageContainer -Context $sa -Name "scripts" -Permission Off

# create the share
$shareName = "deploymentshare"
$share = New-AzureStorageShare -Name $shareName -Context $sa
$connectionpoint = "\\" +  $share.StorageUri.PrimaryUri.Host + "\" + $share.Name
$storageuser = "Azure\" + $storageaccount.StorageAccountName 
##

# create the sas token to access Blob
$expiryTime = (Get-Date).AddHours(4)
$blobsastoken = $sa | Get-AzureStorageContainer -Container scripts | New-AzureStorageContainerSASToken -Permission rwdl -ExpiryTime $expiryTime

# create the sas token to write to file share

$sharesastoken = New-AzureStorageShareSASToken -Context $sa -ShareName $shareName -Permission rwdl -ExpiryTime $expiryTime 

# copy esae deployment files to File Share
dir "D:\a\1\s\deploymentTemplates\PipelineScripts\"
$azCopy = "D:\a\1\s\deploymentTemplates\PipelineScripts\azcopy.exe"


Start-Process -FilePath $azCopy -ArgumentList "cp","D:/a/1/s/deploymentTemplates/deploymentshare","https://$storageAccount.file.core.windows.net/$shareName/$sharesastoken","--recursive=true" -Wait

# add the pipeline variables
Write-Host "##vso[task.setvariable variable=ADDS_TEMPSTORAGEACCOUNT]$storageAccount"
Write-Host "##vso[task.setvariable variable=ADDS_TEMPSTORAGEACCOUNTKEY]$key"
Write-Host "##vso[task.setvariable variable=ADDS_TEMPSTORAGEACCOUNTTOKEN]$blobsastoken"
Write-Host "##vso[task.setvariable variable=SHARECONNECTIONPOINT]$connectionpoint"
Write-Host "##vso[task.setvariable variable=SHAREUSER]$storageuser"
