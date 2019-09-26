<# 
.SYNOPSIS
    Deploy Azure Automation Schedules
.OUTPUTS
    None    
#>
Param (
	#Tier0 Deployment prefix.  Overrides the param value in the paramters file
    [Parameter(Mandatory = $True)] 
	[String]$tier0prefix,
    
    #Name of the automation workspace
	[Parameter(Mandatory = $True)] 
    [String]$aaname,

	#Environment e.g., lab.  Overrides the param value in the paramters file
    [Parameter(Mandatory = $True)] 
	[String]$Environment,
    
	#Name of the deployment e.g, ussc, eastus
    [Parameter(Mandatory = $True)] 
	[String]$deploymentName,
    
	#Time zone of the schedules
	[Parameter(Mandatory = $True)] 
    [String]$umtimezone,

	[Parameter(Mandatory = $True)]
	[string]$startTime
)

$existingSchedules = (Get-AzAutomationSchedule -ResourceGroupName "$($tier0prefix)-logging-rg" -AutomationAccountName $aaname).Name |  where-object {$_ -ne $null} | foreach{$($_.Substring(0,$_.lastindexof('_')))}

if(!($existingSchedules)){
	$existingSchedules = @()
}

$templateFile = (Get-ChildItem $env:SYSTEM_ARTIFACTSDIRECTORY -Recurse -Include updatemgmt.json).FullName

$templateParamFile = (Get-ChildItem $env:SYSTEM_ARTIFACTSDIRECTORY -Recurse ).FullName | Where-Object {$_ -like "*$($Environment)\Logging\updatemgmt.parameters.json*"}

$today = (Get-Date).ToString("yyyy-MM-dd HH:mm")
if($today -gt "06")
{ 
   $updateMgmt = ((Get-Date).AddDays(1)).ToString("yyyy-MM-dd $startTime")
} 
else 
{
    $updateMgmt = (Get-Date).ToString("yyyy-MM-dd $startTime") 
}


New-AzResourceGroupDeployment -ResourceGroupName "$($tier0prefix)-logging-rg" -TemplateFile $templateFile -TemplateParameterFile $templateParamFile -aaname  $aaname -umstartdate $updateMgmt -umtimezone $umtimezone -existingSchedules $existingSchedules

