
configuration DeployNewADDSwithADDNS 
{ 
   param 
   ( 
        [Parameter(Mandatory)]
        [String]$DomainName,

        [String]$DNSServer,
        
        [Parameter(Mandatory)]
        [String]$DSRMPWD,

        [Parameter(Mandatory)]
        [String]$netbiosName,

        
        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$Admincreds,

		[Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$dsrmCreds,
		
        [Int]$RetryCount=20,
        [Int]$RetryIntervalSec=30
    ) 
    
    Import-DscResource -ModuleName xDNS
    Import-DscResource -ModuleName xActiveDirectory, xStorage, networkingdsc

    [System.Management.Automation.PSCredential ]$DomainCreds = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($Admincreds.UserName)", $Admincreds.Password)
    [System.Management.Automation.PSCredential ]$DSRMPWDCreds = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($dsrmCreds.UserName)", $dsrmCreds.Password)
	$Interface=Get-NetAdapter|Where Name -Like "Ethernet*"|Select-Object -First 1
    $InterfaceAlias=$($Interface.Name)
	$dnsFilePath = Join-Path $env:systemdrive "xdnsout\dnsIPs.txt"

    $dn = (Get-Partition | where-object -filterscript { $_.DriveLetter -eq "F" }).DiskNumber
    if (!$dn) { $dn = 2 }

	$domainsplit = $DomainName.Split(".")
    $DomainDN = $null
    foreach ($item in $domainsplit){$DomainDN = $DomainDN + "DC=" + $item + ","}
    $DomainDN = $DomainDN.TrimEnd(",")
	$domainjoinTempOU = "DomainJoinTemp"
	

    Node localhost
    {
		xExportClientDNSAddressesToFile ExportDNSServers
		{
			OutputFilePath = $dnsFilePath
		}

        WindowsFeature DNS 
        { 
            Ensure = "Present" 
            Name = "DNS"
			DependsOn = '[xExportClientDNSAddressesToFile]ExportDNSServers'
        }

        WindowsFeature RSAT-DNS-Server
        {
            Ensure = "Present"
            Name = "RSAT-DNS-Server"
            DependsOn = '[WindowsFeature]DNS'
        }

        DnsServerAddress DnsServerAddress 
        { 
            Address        = '127.0.0.1' 
            InterfaceAlias = $InterfaceAlias
            AddressFamily  = 'IPv4'
            Validate       = $true
			DependsOn = '[WindowsFeature]DNS'
        }
		               
        xWaitforDisk Disk2
        {
             DiskId = $dn
             RetryIntervalSec =$RetryIntervalSec
             RetryCount = $RetryCount
             
        }

        xDisk DataVolume
        {
             DiskId = $dn
             DriveLetter = 'F'
             FSLabel = 'Data'
             DependsOn = '[xWaitForDisk]Disk2'
        }

        WindowsFeature ADDSInstall 
        { 
            Ensure = "Present" 
            Name = "AD-Domain-Services"
			DependsOn = '[xDisk]DataVolume'
        }  

        WindowsFeature ADDSTools
        { 
            Ensure = 'Present' 
            Name = 'RSAT-ADDS' 
        }

        WindowsFeature ADAdminCenter
        {
            Ensure = "Present"
            Name = "RSAT-AD-AdminCenter"
            DependsOn = "[WindowsFeature]ADDSTools"
        }

        xADDomain FirstDS 
        {
            DomainName = $DomainName
            DomainAdministratorCredential = $DomainCreds
            SafemodeAdministratorPassword = $DSRMPWDCreds
            DomainNetBIOSName = $netbiosName
            DatabasePath = "F:\NTDS"
            LogPath = "F:\NTDS"
            SysvolPath = "F:\SYSVOL"
			DependsOn = '[WindowsFeature]ADDSInstall'
        }

		xAddDNSForwardersFromFile AddDNSForwarders
		{
			DNSIPsFilePath = $dnsFilePath
			DependsOn = '[xADDomain]FirstDS'
		}

        xADReplicationSite SecondADSite
        {
           Ensure = 'Present'
           Name   = 'SecondADSite'
           DependsOn = '[xADDomain]FirstDS'
        }

        xADReplicationSite ThirdADSite
        {
           Ensure = 'Present'
           Name   = 'ThirdADSite'
           DependsOn = '[xADDomain]FirstDS'
        }

        xADReplicationSubnet SecondADSiteSubnet
        {
           Ensure = 'Present'
           Name   = '10.3.1.0/24'
           Site   = 'SecondADSite'
           DependsOn = "[xADReplicationSite]SecondADSite"
        }

        xADRecycleBin RecycleBin
        {
           EnterpriseAdministratorCredential = $domainCreds
           ForestFQDN = $DomainName
           DependsOn = '[xADDomain]FirstDS'
        }
		
		xADOrganizationalUnit "DomainJoinTempOU"
        { 
            Name = $domainjoinTempOU
            Ensure = 'Present'
            Path = $DomainDN
			DependsOn = "[xADDomain]FirstDS"
        }
		
        LocalConfigurationManager 
        {
            ActionAfterReboot = 'ContinueConfiguration'
            ConfigurationMode = 'ApplyOnly'
            RebootNodeIfNeeded = $true
            AllowModuleOverWrite = $true
        }

   }
} 


configuration AddDCstoADDSwithADDNS
{ 
   param 
   ( 
        [Parameter(Mandatory)]
        [String]$DomainName,

        [String]$DNSServer,

        
        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$Admincreds,

		[Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$dsrmCreds,
		
        [Int]$RetryCount=20,
        [Int]$RetryIntervalSec=30
    ) 
    
    Import-DscResource -ModuleName xDNS
    Import-DscResource -ModuleName xActiveDirectory, xStorage, xPendingReboot

    [System.Management.Automation.PSCredential ]$DomainCreds = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($Admincreds.UserName)", $Admincreds.Password)
    [System.Management.Automation.PSCredential ]$DSRMPWDCreds = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($dsrmCreds.UserName)", $dsrmCreds.Password)
	$Interface=Get-NetAdapter|Where Name -Like "Ethernet*"|Select-Object -First 1
    $InterfaceAlias=$($Interface.Name)
	$dnsFilePath = Join-Path $env:systemdrive "xdnsout\dnsIPs.txt"

    $dn = (Get-Partition | where-object -filterscript { $_.DriveLetter -eq "F" }).DiskNumber
    if (!$dn) { $dn = 2 }
	
    Node localhost
    {

        xExportClientDNSAddressesToFile ExportDNSServers
		{
			OutputFilePath = $dnsFilePath
		}

		WindowsFeature DNS 
        { 
            Ensure = "Present" 
            Name = "DNS"
            DependsOn = '[xExportClientDNSAddressesToFile]ExportDNSServers'
        }

        xWaitforDisk Disk2
        {
             DiskId = $dn
             RetryIntervalSec =$RetryIntervalSec
             RetryCount = $RetryCount
        }

        xDisk DataVolume
        {
             DiskId = $dn
             DriveLetter = 'F'
             FSLabel = 'Data'
             DependsOn = '[xWaitForDisk]Disk2'
        }

        WindowsFeature ADDSInstall 
        { 
            Ensure = "Present" 
            Name = "AD-Domain-Services"
			DependsOn = '[xDisk]DataVolume'
        }  

        WindowsFeature ADDSTools
        { 
            Ensure = 'Present' 
            Name = 'RSAT-ADDS' 
        }

        WindowsFeature ADAdminCenter
        {
            Ensure = "Present"
            Name = "RSAT-AD-AdminCenter"
            DependsOn = "[WindowsFeature]ADDSTools"
        }

        xWaitForADDomain DscForestWait
        {
            DomainName = $DomainName
            DomainUserCredential= $DomainCreds
            RetryCount = $RetryCount
            RetryIntervalSec = $RetryIntervalSec
        }

        xADDomainController BDC
        {
            DomainName = $DomainName
            DomainAdministratorCredential = $DomainCreds
            SafemodeAdministratorPassword = $DSRMPWDCreds
            DatabasePath = "F:\NTDS"
            LogPath = "F:\NTDS"
            SysvolPath = "F:\SYSVOL"
            DependsOn = "[xWaitForADDomain]DscForestWait"
        }

		xAddDNSForwardersFromFile AddDNSForwarders
		{
			DNSIPsFilePath = $dnsFilePath
			DependsOn = "[xADDomainController]BDC"
		}

        LocalConfigurationManager 
        {
            ActionAfterReboot = 'ContinueConfiguration'
            ConfigurationMode = 'ApplyOnly'
            RebootNodeIfNeeded = $true
            AllowModuleOverWrite = $true
        }

        xPendingReboot RebootAfterPromotion 
        {
            Name = "RebootAfterDCPromotion"
            DependsOn = "[xADDomainController]BDC"
        }

   }
}


configuration DeployNewADDSwithoutADDNS 
{ 
   param 
   ( 
        [Parameter(Mandatory)]
        [String]$DomainName,

        [Parameter(Mandatory)]
        [String]$DNSServer,

        [Parameter(Mandatory)]
        [String]$netbiosName,

        [Parameter(Mandatory)]
        [String]$DSRMPWD,

        
        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$Admincreds,

		[Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$dsrmCreds,
		
        [Int]$RetryCount=20,
        [Int]$RetryIntervalSec=30
    ) 
    
    Import-DscResource -ModuleName xActiveDirectory, xStorage, networkingdsc, xPendingReboot, PSDesiredStateConfiguration

    [System.Management.Automation.PSCredential ]$DomainCreds = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($Admincreds.UserName)", $Admincreds.Password)
    $Interface=Get-NetAdapter|Where Name -Like "Ethernet*"|Select-Object -First 1
    $InterfaceAlias=$($Interface.Name) 
	$dnsFilePath = Join-Path $env:systemdrive "xdnsout\dnsIPs.txt"

    $dn = (Get-Partition | where-object -filterscript { $_.DriveLetter -eq "F" }).DiskNumber
    if (!$dn) { $dn = 2 }

	$domainsplit = $DomainName.Split(".")
    $DomainDN = $null
    foreach ($item in $domainsplit){$DomainDN = $DomainDN + "DC=" + $item + ","}
    $DomainDN = $DomainDN.TrimEnd(",")
	$domainjoinTempOU = "DomainJoinTemp"
	

    Node localhost
    {
		DnsServerAddress DnsServerAddress 
        { 
            Address        = $DNSServer 
            InterfaceAlias = $InterfaceAlias
            AddressFamily  = 'IPv4'
            Validate       = $true
        }

        xWaitforDisk Disk2
        {
             DiskId = $dn
             RetryIntervalSec =$RetryIntervalSec
             RetryCount = $RetryCount
        }

        xDisk DataVolume
        {
             DiskId = $dn
             DriveLetter = 'F'
             FSLabel = 'Data'
             DependsOn = '[xWaitForDisk]Disk2'
        }

        WindowsFeature ADDSInstall 
        { 
            Ensure = "Present" 
            Name = "AD-Domain-Services"
			DependsOn = '[xDisk]DataVolume'
        }  

        WindowsFeature ADDSTools
        { 
            Ensure = 'Present' 
            Name = 'RSAT-ADDS' 
        }

        WindowsFeature ADAdminCenter
        {
            Ensure = "Present"
            Name = "RSAT-AD-AdminCenter"
            DependsOn = "[WindowsFeature]ADDSTools"
        }   

        Script InstallADDS
        {
            SetScript = 
            { 
                $Secure_String_Pwd = ConvertTo-SecureString $using:DSRMPWD -AsPlainText -Force

                Import-Module ADDSDeployment
                Install-ADDSForest `
                -DatabasePath "F:\NTDS" `
                -DomainMode "WinThreshold" `
                -DomainName $using:DomainName `
                -DomainNetbiosName $using:netbiosName `
                -ForestMode "WinThreshold" `
                -InstallDns:$false `
                -LogPath "F:\NTDS" `
                -SysvolPath "F:\SYSVOL" `
                -Force:$true `
                -SafeModeAdministratorPassword $Secure_String_Pwd

            }
            TestScript = { Test-Path "F:\NTDS\ntds.dit" }
            GetScript = { @{} }
            DependsOn  = '[WindowsFeature]ADDSInstall'
            PsDscRunAsCredential = $domainCreds          
        } 

       xADReplicationSite SecondADSite
        {
           Ensure = 'Present'
           Name   = 'SecondADSite'
           DependsOn = "[Script]InstallADDS"
        }

        xADReplicationSite ThirdADSite
        {
           Ensure = 'Present'
           Name   = 'ThirdADSite'
           DependsOn = "[Script]InstallADDS"
        }

        xADReplicationSubnet SecondADSiteSubnet
        {
           Ensure = 'Present'
           Name   = '10.3.1.0/24'
           Site   = 'SecondADSite'
           DependsOn = "[xADReplicationSite]SecondADSite"
        } 

        xADRecycleBin RecycleBin
        {
           EnterpriseAdministratorCredential = $domainCreds
           ForestFQDN = $DomainName
           DependsOn = "[Script]InstallADDS"
        }

		xPendingReboot RebootAfterPromotion 
        {
            Name = "RebootAfterDCPromotion"
            DependsOn = "[Script]InstallADDS"
        }
		
		<# Script Reboot
        {
            SetScript = {
				Start-Sleep -Seconds 90
				Restart-Computer -force
            }
			TestScript = { return $false }
            GetScript = { @{} }
            DependsOn = '[Script]InstallADDS'
			PsDscRunAsCredential = $domainCreds
        }    #>
		
		xADOrganizationalUnit "DomainJoinTempOU"
        { 
            Name = $domainjoinTempOU
            Ensure = 'Present'
            Path = $DomainDN
			DependsOn = "[Script]InstallADDS"
        }
		
        LocalConfigurationManager 
        {
            ActionAfterReboot = 'ContinueConfiguration'
            ConfigurationMode = 'ApplyOnly'
            RebootNodeIfNeeded = $true
            AllowModuleOverWrite = $true
        }

   }
} 


configuration AddDCstoADDSwithoutADDNS
{ 
   param 
   ( 
        [Parameter(Mandatory)]
        [String]$DomainName,

        [Parameter(Mandatory)]
        [String]$DNSServer,
		        
        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$Admincreds,

		[Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$dsrmCreds,
		
        [Int]$RetryCount=20,
        [Int]$RetryIntervalSec=30
    ) 
    
    Import-DscResource -ModuleName xActiveDirectory, xStorage, xPendingReboot, networkingdsc
    
    [System.Management.Automation.PSCredential ]$DomainCreds = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($Admincreds.UserName)", $Admincreds.Password)
    [System.Management.Automation.PSCredential ]$DSRMPWDCreds = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($dsrmCreds.UserName)", $dsrmCreds.Password)
	$Interface=Get-NetAdapter|Where Name -Like "Ethernet*"|Select-Object -First 1
    $InterfaceAlias=$($Interface.Name)
	$dnsFilePath = Join-Path $env:systemdrive "xdnsout\dnsIPs.txt"

    $dn = (Get-Partition | where-object -filterscript { $_.DriveLetter -eq "F" }).DiskNumber
    if (!$dn) { $dn = 2 }
	
    Node localhost
    {

        DnsServerAddress DnsServerAddress 
        { 
            Address        = $DNSServer 
            InterfaceAlias = $InterfaceAlias
            AddressFamily  = 'IPv4'
            Validate       = $true
        }

        xWaitforDisk Disk2
        {
             DiskId = $dn
             RetryIntervalSec =$RetryIntervalSec
             RetryCount = $RetryCount
        }

        xDisk DataVolume
        {
             DiskId = $dn
             DriveLetter = 'F'
             FSLabel = 'Data'
             DependsOn = '[xWaitForDisk]Disk2'
        }

        WindowsFeature ADDSInstall 
        { 
            Ensure = "Present" 
            Name = "AD-Domain-Services"
			DependsOn = '[xDisk]DataVolume'
        }

        WindowsFeature ADDSTools
        { 
            Ensure = 'Present' 
            Name = 'RSAT-ADDS' 
        }

        WindowsFeature ADAdminCenter
        {
            Ensure = "Present"
            Name = "RSAT-AD-AdminCenter"
            DependsOn = "[WindowsFeature]ADDSTools"
        }

        xWaitForADDomain DscForestWait
        {
            DomainName = $DomainName
            DomainUserCredential= $DomainCreds
            RetryCount = $RetryCount
            RetryIntervalSec = $RetryIntervalSec
        }

        xADDomainController BDC
        {
            DomainName = $DomainName
            DomainAdministratorCredential = $DomainCreds
            SafemodeAdministratorPassword = $DSRMPWDCreds
            DatabasePath = "F:\NTDS"
            LogPath = "F:\NTDS"
            SysvolPath = "F:\SYSVOL"
            DependsOn = "[xWaitForADDomain]DscForestWait"
        }

        LocalConfigurationManager 
        {
            ActionAfterReboot = 'ContinueConfiguration'
            ConfigurationMode = 'ApplyOnly'
            RebootNodeIfNeeded = $true
            AllowModuleOverWrite = $true
        }

        xPendingReboot RebootAfterPromotion 
        {
            Name = "RebootAfterDCPromotion"
            DependsOn = "[xADDomainController]BDC"
        }

   }
}

