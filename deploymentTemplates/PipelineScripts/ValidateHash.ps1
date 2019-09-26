# This script will validate the hash on the binary
# If hash matches the predefined good known value then it will exit, if it does not match it will stop with fail

# ---> Have not been testest <----

Param(
    [Parameter(Mandatory = $true)][string] $targetFile, #specify path to file 
	[Parameter(Mandatory = $true)][string] $KnownGoodHash, #specify path to file 
    
)
Set-StrictMode -Off
$Global:TokenSets = $null
$ErrorActionPreference = 'Stop' 

$basePath=Resolve-Path ((gci -recurse -filter "VvalidateHash.ps1").DirectoryName+'\..\')    
Write-warning "Azure DevOps Hosted Agent Pipeline found. Starting from $basePath"

$TargetBinaryFile = "$($basePath)deploymentTemplates\$targetFile" 

# calculate hash on the target file

$hashFromFile = Get-FileHash -Path $TargetBinaryFile -Algorithm SHA256

# Check both hashes are the same
if ($hashFromFile.Hash -eq $KnownGoodHash) {
	Write-Host 'Get-FileHash results are consistent' -ForegroundColor Green
} else {
	Write-Host 'Get-FileHash results are inconsistent!!' -ForegroundColor Red
	
	throw ("Get-FileHash results are inconsistent!!")
}
