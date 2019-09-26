
param (
    [string]$firstDCupdate,
	[string]$secondDCupdate,
	[string]$vNetRG,
    [string]$vNetName,
    [string]$dns1IP,
	[string]$dns2IP

)

# https://docs.microsoft.com/en-us/powershell/module/AzureRM.Network/Get-AzureRmVirtualNetwork?view=azurermps-6.13.0 


if ($firstDCupdate -eq "yes")
 {
	#$vnet = Get-AzVirtualNetwork -ResourceGroupName $vNetRG -name $vNetName
	$vnet = Get-AzureRmVirtualNetwork -ResourceGroupName $vNetRG -name $vNetName
	$vnet.DhcpOptions.DnsServers = $dns1IP
	#Set-AzVirtualNetwork -VirtualNetwork $vnet
	Set-AzureRmVirtualNetwork -VirtualNetwork $vnet
 }
 else
 {
	# 
 }

 
if ($secondDCupdate -eq "yes")
 {
	#$vnet = Get-AzVirtualNetwork -ResourceGroupName $vNetRG -name $vNetName
	$vnet = Get-AzureRmVirtualNetwork -ResourceGroupName $vNetRG -name $vNetName
	$vnet.DhcpOptions.DnsServers = $dns1IP
	$vnet.DhcpOptions.DnsServers += $dns2IP
	#Set-AzVirtualNetwork -VirtualNetwork $vnet
	Set-AzureRmVirtualNetwork -VirtualNetwork $vnet
 }
 else
 {
	#
 }