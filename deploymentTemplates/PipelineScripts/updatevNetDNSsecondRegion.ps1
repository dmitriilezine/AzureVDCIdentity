
param (
    [string]$secondRegionUpdate,
	[string]$thirdDCupdate,
	[string]$forthDCupdate,
	[string]$vNetRG,
    [string]$vNetName,
    [string]$dns1IP,
	[string]$dns2IP,
	[string]$dns3IP,
	[string]$dns4IP
)

# https://docs.microsoft.com/en-us/powershell/module/AzureRM.Network/Get-AzureRmVirtualNetwork?view=azurermps-6.13.0 


if ($secondRegionUpdate -eq "yes")
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

if ($thirdDCupdate -eq "yes")
 {
	#$vnet = Get-AzVirtualNetwork -ResourceGroupName $vNetRG -name $vNetName
	$vnet = Get-AzureRmVirtualNetwork -ResourceGroupName $vNetRG -name $vNetName
	$vnet.DhcpOptions.DnsServers = $dns3IP
	$vnet.DhcpOptions.DnsServers += $dns1IP
	$vnet.DhcpOptions.DnsServers += $dns2IP
	#Set-AzVirtualNetwork -VirtualNetwork $vnet
	Set-AzureRmVirtualNetwork -VirtualNetwork $vnet
 }
 else
 {
	# 
 }

 
if ($forthDCupdate -eq "yes")
 {
	#$vnet = Get-AzVirtualNetwork -ResourceGroupName $vNetRG -name $vNetName
	$vnet = Get-AzureRmVirtualNetwork -ResourceGroupName $vNetRG -name $vNetName
	$vnet.DhcpOptions.DnsServers = $dns3IP
	$vnet.DhcpOptions.DnsServers += $dns4IP
	$vnet.DhcpOptions.DnsServers += $dns1IP
	$vnet.DhcpOptions.DnsServers += $dns2IP
	#Set-AzVirtualNetwork -VirtualNetwork $vnet
	Set-AzureRmVirtualNetwork -VirtualNetwork $vnet
 }
 else
 {
	#
 }