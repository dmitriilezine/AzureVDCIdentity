configuration InstallADFSFarm
{ 
   param 
   ( 
        [Parameter(Mandatory)]
        [String]$DomainName,

        [Parameter(Mandatory)]
        [String]$CACommonName,

        [Parameter(Mandatory)]
        [String]$ADFSDNSName,

        [Parameter(Mandatory)]
        [String]$ADFSServiceCert,

        [Parameter(Mandatory)]
        [String]$PrimaryADFSServer,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$Admincreds,

		[Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$ADFSWAPDeploycreds,

        [Parameter(Mandatory)]
        [string]$TargetDIADOU,

        [Parameter(Mandatory)]
        [string]$ComputerDN,

	    [Parameter(Mandatory)]
        [string]$shortdomainname,

	    [Parameter(Mandatory)]
        [string]$svcADFS,

	    [Parameter(Mandatory)]
        [string]$ADFSGGName,

	    [Parameter(Mandatory)]
        [string]$ADFSServerName,

		[Parameter(Mandatory)]
        [string]$adfswapdeploymentaccount,
		
        [Int]$RetryCount=20,
        [Int]$RetryIntervalSec=30
    ) 
    
    $logdir = "c:\InstallADFSLogs"

    Import-DscResource -ModuleName PSDesiredStateConfiguration
    [System.Management.Automation.PSCredential ]$DomainCreds = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($Admincreds.UserName)", $Admincreds.Password)
       
    Node localhost
    {
		LocalConfigurationManager 
        {
            ActionAfterReboot = 'ContinueConfiguration'
            ConfigurationMode = 'ApplyOnly'
            RebootNodeIfNeeded = $true
            AllowModuleOverWrite = $true
        }

        WindowsFeature installADFS
        {
            Ensure = "Present"
            Name   = "ADFS-Federation"
            DependsOn = '[WindowsFeature]RSATADPowerShell'
        }

         WindowsFeature RSATADPowerShell
        {
            Ensure = "Present"
            Name = "RSAT-AD-PowerShell"
        }

        Script CreateLogFolder
        {
            SetScript = 
            { 
                New-Item -ItemType Directory $using:logdir
                $LogFile = ("Test.log") 
                $Log = "$using:logdir\$LogFile"
                $sw = New-Object System.IO.StreamWriter($Log)
                $sw.Close()
            }
            TestScript = { Test-Path "c:\InstallADFSLogs\Test.log" }
            GetScript = { @{} }          
        }

         Script Reboot
        {
            TestScript = {
                return (Test-Path HKLM:\SOFTWARE\MyMainKey\RebootKey)
            }
            SetScript = {
                New-Item -Path HKLM:\SOFTWARE\MyMainKey\RebootKey -Force
                 $global:DSCMachineStatus = 1 

            }
            GetScript = { return @{result = 'result'}}
            DependsOn = '[WindowsFeature]installADFS'
        }    

		Script InstallADFS
        {
            SetScript = 
            { 
                certutil -pulse
                Start-Sleep -Seconds 15

                Import-Module ADFS

                $CertThumb = Get-ChildItem -Path Cert:\LocalMachine\My | where {$PSItem.Subject -like “*$using:ADFSServiceCert*” } | Select -ExpandProperty Thumbprint  
                if (!($certThumb))
                {
                   write-host "cert does not exist..."

                }
                else
                {
                    
					$ADFSServer = "$using:ADFSServerName" + "$"
					Add-adgroupmember –Identity $using:ADFSGGName –members $ADFSServer -Credential $using:domainCreds

					$purgeKrbCmd = "klist -li 0x3e7 purge"
					Invoke-Expression $purgeKrbCmd

					Start-Sleep -Seconds 90

					Install-ADServiceaccount -Identity $using:svcADFS

					$GSAI = "$using:shortdomainname" + "\" + "$using:svcADFS" + "$"
					Install-AdfsFarm -CertificateThumbprint $CertThumb -Credential $using:domainCreds `
                        -FederationServiceName $using:ADFSServiceCert -FederationServiceDisplayName "Active Directory Federation Service" `
                        -GroupServiceAccountIdentifier $GSAI 
					 
                }

            }
            TestScript = {  

				$adfs = get-service -name adfssrv
				if (( $adfs.Status -eq "Running" ))
				{ 
					return $true 
				}
				else
				{
					return $false
				}
			
			}
            GetScript = { @{} }
            DependsOn  = '[Script]Reboot'
        }

		Script AddADFSWAPDeploymentAccountToAdministrators
        {
            SetScript = 
            { 
					#Add ASFS & WAP deployment account to local administrators group
					$adfswapdeploymentaccountname = "$using:shortdomainname" + "\" + "$using:adfswapdeploymentaccount"
					Add-LocalGroupMember -Group "Administrators" -Member $adfswapdeploymentaccountname
	                
            }
            TestScript = { 
				    
					$adfswapdeploymentaccountname = "$using:shortdomainname" + "\" + "$using:adfswapdeploymentaccount"
					$ErrorActionPreference = 'SilentlyContinue'
					$getLocalMember = Get-LocalGroupMember -Group "Administrators" -Member $adfswapdeploymentaccountname | select -expandproperty name
					if (($getLocalMember))
					{
						return $true
					}
					else
					{
						return $false
	                }
			
			}
            GetScript = { @{} }          
        }
 
   }
} 

configuration InstallADFSFarmonADFSvm2
{ 
   param 
   ( 
        [Parameter(Mandatory)]
        [String]$DomainName,

        [Parameter(Mandatory)]
        [String]$CACommonName,

        [Parameter(Mandatory)]
        [String]$ADFSDNSName,

        [Parameter(Mandatory)]
        [String]$ADFSServiceCert,

        [Parameter(Mandatory)]
        [String]$PrimaryADFSServer,
        
        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$Admincreds,

		[Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$ADFSWAPDeploycreds,

        [Parameter(Mandatory)]
        [string]$TargetDIADOU,

        [Parameter(Mandatory)]
        [string]$ComputerDN,

	    [Parameter(Mandatory)]
        [string]$shortdomainname,

	    [Parameter(Mandatory)]
        [string]$svcADFS,

	    [Parameter(Mandatory)]
        [string]$ADFSGGName,

	    [Parameter(Mandatory)]
        [string]$ADFSServerName,

		[Parameter(Mandatory)]
        [string]$adfswapdeploymentaccount,
		
        [Int]$RetryCount=20,
        [Int]$RetryIntervalSec=30
    ) 
    
    $logdir = "c:\InstallADFSLogs"

    Import-DscResource -ModuleName PSDesiredStateConfiguration
    [System.Management.Automation.PSCredential ]$DomainCreds = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($Admincreds.UserName)", $Admincreds.Password)
    [System.Management.Automation.PSCredential ]$ADFSWAPCreds = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($ADFSWAPDeploycreds.UserName)", $ADFSWAPDeploycreds.Password)
      
    Node localhost
    {
		LocalConfigurationManager 
        {
            ActionAfterReboot = 'ContinueConfiguration'
            ConfigurationMode = 'ApplyOnly'
            RebootNodeIfNeeded = $true
            AllowModuleOverWrite = $true
        }

        WindowsFeature installADFS
        {
            Ensure = "Present"
            Name   = "ADFS-Federation"
            DependsOn = '[WindowsFeature]RSATADPowerShell'
        }

        WindowsFeature RSATADPowerShell
        {
            Ensure = "Present"
            Name = "RSAT-AD-PowerShell"
        }


        Script CreateLogFolder
        {
            SetScript = 
            { 
                New-Item -ItemType Directory $using:logdir
                $LogFile = ("Test.log") 
                $Log = "$using:logdir\$LogFile"
                $sw = New-Object System.IO.StreamWriter($Log)
                $sw.Close()
            }
            TestScript = { Test-Path "c:\InstallADFSLogs\Test.log" }
            GetScript = { @{} }          
        }

       
         Script Reboot
        {
            TestScript = {
                return (Test-Path HKLM:\SOFTWARE\MyMainKey\RebootKey)
            }
            SetScript = {
                New-Item -Path HKLM:\SOFTWARE\MyMainKey\RebootKey -Force
                 $global:DSCMachineStatus = 1 

            }
            GetScript = { return @{result = 'result'}}
            DependsOn = '[WindowsFeature]installADFS'
        }    


        Script InstallADFS
        {
            SetScript = 
            { 
                certutil -pulse
                Start-Sleep -Seconds 15

               Import-Module ADFS

                $CertThumb = Get-ChildItem -Path Cert:\LocalMachine\My | where {$PSItem.Subject -like “*$using:ADFSServiceCert*” } | Select -ExpandProperty Thumbprint  
                if (!($certThumb))
                {
                    
                    write-host "cert does not exist..."
                }
                else
                {
                   	$ADFSServer = "$using:ADFSServerName" + "$"
					Add-adgroupmember –Identity $using:ADFSGGName –members $ADFSServer -Credential $using:DomainCreds

					$purgeKrbCmd = "klist -li 0x3e7 purge"
					Invoke-Expression $purgeKrbCmd

					Start-Sleep -Seconds 90

					Install-ADServiceaccount -Identity $using:svcADFS
					
					$GSAI = "$using:shortdomainname" + "\" + "$using:svcADFS" + "$"
					Add-AdfsFarmNode -OverwriteConfiguration -CertificateThumbprint $CertThumb -Credential $using:DomainCreds `
						-GroupServiceAccountIdentifier $GSAI -PrimaryComputerName $using:PrimaryADFSServer -PrimaryComputerPort 80			

                }

            }
            TestScript = { 
				
				$adfs = get-service -name adfssrv
				if (( $adfs.Status -eq "Running" ))
								
				{ 
					return $true 
				}
				else
				{
					return $false
				}
			}
            GetScript = { @{} }
            DependsOn  = '[Script]Reboot'
        }

		Script AddADFSWAPDeploymentAccountToAdministrators
        {
            SetScript = 
            { 
					#Add ASFS & WAP deployment account to local administrators group
					$adfswapdeploymentaccountname = "$using:shortdomainname" + "\" + "$using:adfswapdeploymentaccount"
					Add-LocalGroupMember -Group "Administrators" -Member $adfswapdeploymentaccountname
	                
            }
            TestScript = { 
				    
					$adfswapdeploymentaccountname = "$using:shortdomainname" + "\" + "$using:adfswapdeploymentaccount"
					$ErrorActionPreference = 'SilentlyContinue'
					$getLocalMember = Get-LocalGroupMember -Group "Administrators" -Member $adfswapdeploymentaccountname | select -expandproperty name
					if (($getLocalMember))
					{
						return $true
					}
					else
					{
						return $false
	                }
			
			}
            GetScript = { @{} }          
        }

   }
} 


configuration InstallWebApplicationProxy
{ 
   param 
   ( 
        [Parameter(Mandatory)]
        [String]$DomainName,
	                   
        [Parameter(Mandatory)]
        [String]$ADFSServiceCert,
	                   
		[Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$ADFSWAPDeploycreds,
	           
        [Parameter(Mandatory)]
        [string]$ADFSServerIP,
		
        [Int]$RetryCount=20,
        [Int]$RetryIntervalSec=30
    ) 
    
    $logdir = "c:\InstallADFSLogs"

    Import-DscResource -ModuleName PSDesiredStateConfiguration
    [System.Management.Automation.PSCredential ]$ADFSWAPCreds = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($ADFSWAPDeploycreds.UserName)", $ADFSWAPDeploycreds.Password)
        
    Node localhost
    {
		LocalConfigurationManager 
        {
            ActionAfterReboot = 'ContinueConfiguration'
            ConfigurationMode = 'ApplyOnly'
            RebootNodeIfNeeded = $true
            AllowModuleOverWrite = $true
        }

		WindowsFeature RSATADPowerShell
        {
            Ensure = "Present"
            Name = "RSAT-AD-PowerShell"
        }
       		
		WindowsFeature installWAP
        {
            Ensure = "Present"
            Name   = "Web-Application-Proxy"
            DependsOn = '[WindowsFeature]RSATADPowerShell'
        }
		 
		#Install Feature "Remote Access Management Tools"
		 WindowsFeature RSAT-RemoteAccess
		{
		    Ensure = "Present"
		    Name = "RSAT-RemoteAccess"
		}                
	     
		 #Install Feature "Remote Access GUI and Command-Line Tools"
		  WindowsFeature RSAT-RemoteAccess-Mgmt
		{
		    Ensure = "Present"
		    Name = "RSAT-RemoteAccess-Mgmt"
		}
	     #Install Feature "Remote Access module for Windows PowerShell"
		  WindowsFeature RSAT-RemoteAccess-PowerShell
		{
		     Ensure = "Present"
		     Name = "RSAT-RemoteAccess-PowerShell"
		}                      

        Script CreateLogFolder
        {
            SetScript = 
            { 
                New-Item -ItemType Directory $using:logdir
                $LogFile = ("Test.log") 
                $Log = "$using:logdir\$LogFile"
                $sw = New-Object System.IO.StreamWriter($Log)
                $sw.Close()
            }
            TestScript = { Test-Path "c:\InstallADFSLogs\Test.log" }
            GetScript = { @{} }          
        }

       Script CreateHostsFile
        {
            SetScript = 
            { 
                copy-item -path "C:\Windows\System32\drivers\etc\hosts" -destination $using:logdir -Confirm:$false
				$sw = New-Object System.IO.StreamWriter("C:\Windows\System32\drivers\etc\hosts")
                $sw.WriteLine("$using:ADFSServerIP $using:ADFSServiceCert")
                $sw.WriteLine("127.0.0.1 localhost")
                $sw.Close()

            }
            TestScript = { return $false }
            GetScript = { @{} }
            DependsOn  = '[WindowsFeature]installWAP'          
        }
         
         
         Script Reboot
        {
            TestScript = {
                return (Test-Path HKLM:\SOFTWARE\MyMainKey\RebootKey)
            }
            SetScript = {
                New-Item -Path HKLM:\SOFTWARE\MyMainKey\RebootKey -Force
                 $global:DSCMachineStatus = 1 

            }
            GetScript = { return @{result = 'result'}}
            DependsOn = '[Script]CreateHostsFile'
        }    

        
        Script InstallWebApplicationProxy
        {
            SetScript = 
            { 
                certutil -pulse
                Start-Sleep -Seconds 15

               Import-Module webapplicationproxy

                $CertThumb = Get-ChildItem -Path Cert:\LocalMachine\My | where {$PSItem.Subject -like “*$using:ADFSServiceCert*” } | Select -ExpandProperty Thumbprint  
                if (!($certThumb))
                {
                    
                    write-host "cert does not exist..."
                }
                else
                {
                    Install-WebApplicationProxy -FederationServiceName $using:ADFSServiceCert -FederationServiceTrustCredential $using:ADFSWAPCreds -CertificateThumbprint $CertThumb
               
                }

            }
            TestScript = { 
			
			#check if WAP service is running. If yes, then do not install WAP
			$wap = get-service -name appproxysvc
				if (( $wap.Status -eq "Running" ))
								
				{ 
					return $true 
				}
				else
				{
					return $false
				}
						
			}
            GetScript = { @{} }
            DependsOn  = '[Script]Reboot'          
        }

        Script RemoveADFSfromHostsFile
        {
            SetScript = 
            { 
                # Rename-Item -Path "C:\Windows\System32\drivers\etc\hosts" -NewName "hosts.temp" -Force
				# Rename-Item -Path "C:\Windows\System32\drivers\etc\hosts.original" -NewName "hosts" -Force
				$sw = New-Object System.IO.StreamWriter("C:\Windows\System32\drivers\etc\hosts")
                $sw.WriteLine("127.0.0.1 localhost")
                $sw.Close()

                ipconfig /flushdns

            }
            TestScript = { return $false }
            GetScript = { @{} }
            DependsOn  = '[Script]InstallWebApplicationProxy'          
        }

   }
} 