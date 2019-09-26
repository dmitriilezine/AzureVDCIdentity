Param(
    [Parameter(Mandatory = $true)][string] $deploymentName, #usually a region
    [ValidateSet("DEV", "LAB", "PRD")] [Parameter(Mandatory = $true)][string] $environment,
    [Parameter(Mandatory = $false)][switch] $validationMode
)
Set-StrictMode -Off
$Global:TokenSets = $null
$ErrorActionPreference = 'Stop'  

Write-warning "About to check whether deployment is manual or using Pipeline"

if ($env:system_DefaultWorkingDirectory) {
    $basePath=Resolve-Path ((gci -recurse -filter "pipelineConfiguration.ps1").DirectoryName+'\..\')    
    Write-warning "DevOps Hosted Agent Pipeline found. Starting from $basePath"
    $DeployScriptsParametersFile = "$($basePath)deploymentConfigurations\$deploymentName\$environment\configuration.json" 


    if (test-path $DeployScriptsParametersFile) {
        write-warning "About to include $($DeployScriptsParametersFile) file"
        write-warning ". $($DeployScriptsParametersFile)"
    }
}
else {
    write-warning "About to use local files." 
    $DeployScriptsParametersFile = ".\deploymentConfigurations\$deploymentName\$environment\configuration.json"
}

$configRoot = (Get-Content $DeployScriptsParametersFile) | ConvertFrom-Json

Write-Host "##vso[task.setvariable variable=Environment]$environment"
$regex = '\{([^\}]+)\}'
$vars = @{
    environment = $environment
}
$configRoot.PSObject.Properties | ForEach-Object {
    $currentVar = $_.Value
    if ($_.Name -eq "prefix" -and $validationMode) {
        $currentVar = $currentVar + "v"
    }
    Select-String $regex -input $_.Value -AllMatches | ForEach-Object {
        $_.Matches | ForEach-Object {            
            Write-Host "Replacing $($_.Value) with..."
            Write-Host "$($vars[$($_.Value.Replace('{','').Replace('}',''))])"
            $currentVar = $currentVar.Replace($_.Value, $($vars[$($_.Value.Replace('{', '').Replace('}', ''))]))
        }
    }
    Write-Host "$($_.Name) : $currentVar"
    $vars[$_.Name] = $currentVar     
    Write-Host "##vso[task.setvariable variable=$($_.Name)]$($vars[$_.Name])"
}
