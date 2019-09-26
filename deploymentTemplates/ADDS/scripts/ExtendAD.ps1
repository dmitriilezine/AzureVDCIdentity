#
# ExtendAD.ps1

Param (
    [string]$adminUsername,
    [string]$password,
    [string]$domainjoinuser,
    [string]$domainjoinpassword,
	[string]$domainFQDN,
    [string]$upn,
    [string]$Tier0ServerOperatorsSG,
    [string]$svcADFS,
    [string]$ServiceAccountsOU,
    [string]$domainname,
    [string]$shortname,
    [string]$DCvmName,
	[string]$ADFSGGName,
	[string]$ADFSServiceCert,
	[string]$deployDIAD,
	[string]$adcsDeployment,
	[string]$deployADFSgMSA,
	[string]$deployADFSWAPDeploymentAccount,
	[string]$adfswapdeploymentaccount,
	[string]$adfswapdeploymentaccountpwd,
	[string]$deploy2016DCs,
	[string]$deploy2019DCs

)

# Create Script root folder where installation scripts can be expanded
$scriptroot = "c:\ExtendAD"
New-Item -ItemType Directory $scriptroot


# Install Custom Certifcate Templates in ADDS
if ($adcsDeployment -eq "Yes")
{
    # to do - envelop this into Try/Catch
	
	$scripts = "c:\ExtendAD\ADCSscripts"
    New-Item -ItemType Directory $scripts
    Expand-Archive .\scripts\createCertTemplates.zip $scripts -Force

	# Wait 15 seconds
	Start-Sleep -Seconds 15

    # Create Certificate Templates
    powershell -ExecutionPolicy Unrestricted -File $scripts\Create-CertificateTemplates.ps1

}
else
{
     $Action = "Deployment of the ADCS Custom Templates is not performed"
     $Trace += "$Action `r`n"   
     $Trace += "Exiting Script."
     $Trace += "`r`n"
     $LogPath = "c:\temp\SkipDeployADCSCustomTemplates.log"
     $TestPath = Test-Path "c:\temp"
     if ($TestPath -eq $false)
        {
           $mkdir = mkdir "c:\temp"
        }
     $WriteFile = Add-Content -Path $LogPath -Value $Trace
}


# Deploy DIAD OUs and GPOs. This section should be turned off after initial deployment of the OUs and GPOs is done. 
# GPOs will be managed via on-presmies based tools. Continious application of this script will overwrite any changes perforned to GPOs via standard tools.
if ($deployDIAD -eq "Yes")
{
                         
	Try 
		{
		$Trace = "-"
		$Action = "Deploy DIAD OUs and GPOs"
		$Trace += "$Action `r`n"   

		# Extract DIAD scripts from archive
		$diadscripts = "c:\ExtendAD\DIADscripts"
		New-Item -ItemType Directory $diadscripts
		Expand-Archive .\scripts\ExportImportAD.zip $diadscripts -Force

		# Wait 15 seconds
		Start-Sleep -Seconds 15

		# Import DIAD OUs/GPOs
		cd $diadscripts
		$diadversion = "4"
		
		# DIADv3.7
		# Old version of DIAD
		if ($diadversion -eq "3.7")
		{
			powershell -ExecutionPolicy Unrestricted -File "$diadscripts\ExportImport-AD.ps1" -RestoreAll -restorepolicies -LinkGPOs -Link2016 -LinkDomainPolicies -RedirectComputersContainers -BackupFolder "$diadscripts\" -SettingsFile "$diadscripts\settings.xml" -force
			
			# Wait 30 seconds
			Start-Sleep -Seconds 30

			# copy the ADMXs to the domain controller
			powershell -ExecutionPolicy Unrestricted -File "$diadscripts\ImportADMXs.ps1" -backupfolder "$diadscripts\"
		}
		else {
			$Action = "DIAD v3.7 was not run"
			$Trace += "$Action `r`n"  
		}


		# DIADv4
		if ($diadversion -eq "4")
		{
			
			# Link policies based on Domain Controller OS version
			if ($deploy2016DCs -eq "Yes")
			{
				$Action = "Run ExportImport and link 2016 Domain Contoller GPOs"
				$Trace += "$Action `r`n"   
				powershell -ExecutionPolicy Unrestricted -File "$diadscripts\ExportImport-AD.ps1" -RestoreAll -LinkGPOs -Link2016 -Link2016DomainPolicies -RedirectComputersContainers -BackupFolder "$diadscripts\" -SettingsFile "$diadscripts\settings.xml" -force

			}
			else {
				$Action = "2016 Domain Controller GPOs were not linked"
				$Trace += "$Action `r`n"  
			}

			if ($deploy2019DCs -eq "Yes")
			{
				$Action = "Run ExportImport and link 2019 Domain Contoller GPOs"
				$Trace += "$Action `r`n"  
				powershell -ExecutionPolicy Unrestricted -File "$diadscripts\ExportImport-AD.ps1" -RestoreAll -LinkGPOs -Link2019 -Link2019DomainPolicies -RedirectComputersContainers -BackupFolder "$diadscripts\" -SettingsFile "$diadscripts\settings.xml" -force

			}
			else {
				$Action = "2019 Domain Controller GPOs were not linked"
				$Trace += "$Action `r`n"  
			}

			# Wait 30 seconds
			Start-Sleep -Seconds 30

			# copy the ADMXs to the domain controller
			$Action = "Run ImportADMX"
			$Trace += "$Action `r`n"   
			powershell -ExecutionPolicy Unrestricted -File "$diadscripts\ImportADMXs.ps1" -backupfolder "$diadscripts\"

			# Wait 30 seconds
			Start-Sleep -Seconds 15

			# redirect conputer join to quarantibe OU
			#$Action = "Run RedirectComputersContainer.ps1"
			#$Trace += "$Action `r`n"  
			#powershell -ExecutionPolicy Unrestricted -File "$diadscripts\RedirectComputersContainer.ps1"
		}
		else {
			$Action = "DIADv4 was not run"
			$Trace += "$Action `r`n"  
		}

		Start-Sleep -Seconds 15

		# Add Domain Admin accont to Tier0ServerOperators security group
		$Action = "Add Domain Admin accont to Tier0ServerOperators security group"
		$Trace += "$Action `r`n"  
		Add-ADGroupMember -Identity $Tier0ServerOperatorsSG -members $adminUsername

		# Change password on DomainJoin account and enable it
		$Action = "Change password on DomainJoin account and enable it"
		$Trace += "$Action `r`n"  
		Set-ADAccountPassword -Identity $domainjoinuser -Reset -NewPassword (ConvertTo-SecureString -AsPlainText $domainjoinpassword -Force)
		Enable-ADAccount -Identity $domainjoinuser
		               
		}
	Catch
		{
		$Trace += "Exception caught in action '$Action'... `r`n"
		$ErrorState = 2
		$ErrorMessage = $error[0].Exception.tostring()
		$Trace +=  $PSItem.ErrorID
		$Trace +=  $PSItem.Exception.Message
		}
	Finally
		{
		$Trace += "Exiting Script."
		$Trace += "`r`n"
		$LogPath = "c:\temp\DeployDIADOUsGPOs.log"
		$TestPath = Test-Path "c:\temp"
		if ($TestPath -eq $false)
		  {
			  $mkdir = mkdir "c:\temp"
		  }
		 $WriteFile = Add-Content -Path $LogPath -Value $Trace
		}
					
}
else
{
     $Trace = "-"
	 $Action = "Deployment of the DIAD OUs and GPOs is not performed"
     $Trace += "$Action `r`n"   
     $Trace += "Exiting Script."
     $Trace += "`r`n"
     $LogPath = "c:\temp\SkipDeployDIADOUsGPOs.log"
     $TestPath = Test-Path "c:\temp"
     if ($TestPath -eq $false)
        {
           $mkdir = mkdir "c:\temp"
        }
     $WriteFile = Add-Content -Path $LogPath -Value $Trace
}

# Create domain join account, currently add it to the Domain Admins group. This code should be modified to delegate this account to allow to join
# computer to domain, not DA rights
if ($deployDIAD -ne "Yes")
{
								
		$error.Clear()
				
		try
		{
			# Create DomainJoin account and grant it rights 
			New-ADUser -name $domainjoinuser -AccountPassword (ConvertTo-SecureString $domainjoinpassword -AsPlainText -Force) -Enabled 1
			Add-ADGroupMember -Identity "Domain Admins" -Members $domainjoinuser
		}
		catch
		{
			 $Trace = "-"
			 $Action = "ERROR: Unable to create domain join account to join computers to the domain"
			 $Trace += "$Action `r`n"   
			 $Trace += "Exiting Script."
			 $Trace += "`r`n"
			 $LogPath = "c:\temp\UnableGrantDomainJoinSA.log"
			 $TestPath = Test-Path "c:\temp"
			 if ($TestPath -eq $false)
				{
				   $mkdir = mkdir "c:\temp"
				}
			 $WriteFile = Add-Content -Path $LogPath -Value $Trace

		}
		If(!$error)
		{
			 $Trace = "-"
			 $Action = "INFORMATION: Created the domain join account to join computers to the domain"
			 $Trace += "$Action `r`n"   
			 $Trace += "Exiting Script."
			 $Trace += "`r`n"
			 $LogPath = "c:\temp\GrantDomainJoinSA.log"
			 $TestPath = Test-Path "c:\temp"
			 if ($TestPath -eq $false)
				{
				   $mkdir = mkdir "c:\temp"
				}
			 $WriteFile = Add-Content -Path $LogPath -Value $Trace

		}

}
else
{
	 $Trace = "-"
	 $Action = "Deployment of the standalone Domain Join service account is not performed"
     $Trace += "$Action `r`n"   
     $Trace += "Exiting Script."
     $Trace += "`r`n"
     $LogPath = "c:\temp\SkipDeployDomainJoinSA.log"
     $TestPath = Test-Path "c:\temp"
     if ($TestPath -eq $false)
        {
           $mkdir = mkdir "c:\temp"
        }
     $WriteFile = Add-Content -Path $LogPath -Value $Trace
}


# Create ADFS gMSA service account for ADFS farm
if ($deployADFSgMSA -eq "Yes")
{

	# Create Root key for gMSA
	$KDS = (Get-KdsRootKey).KeyId
	 if (($KDS))
		 {
			 # KDS already exist
			 # https://docs.microsoft.com/en-us/powershell/module/kds/get-kdsrootkey?view=win10-ps 
		 }
		 else
		 {
			 Add-KdsRootKey -EffectiveTime ((get-date).addhours(-10))
		 }

	 # Create security group for gMSA use
	 New-ADGroup -Name $ADFSGGName -SamAccountName $ADFSGGName -GroupCategory Security -GroupScope Global -Description "gMSA Group"
 
	 # Create gMSA servvice account
	 $adfsDNShostname = "$svcADFS" + "." + "$domainname"
	 New-ADServiceAccount -name $svcADFS -DNSHostName $adfsDNShostname -PrincipalsAllowedToRetrieveManagedPassword $ADFSGGName -ServicePrincipalNames HOST/$ADFSServiceCert
}
else
{
	 $Trace = "-"
	 $Action = "Deployment of the ADFS gMSA service account is not performed"
     $Trace += "$Action `r`n"   
     $Trace += "Exiting Script."
     $Trace += "`r`n"
     $LogPath = "c:\temp\SkipDeployADFSgMSA.log"
     $TestPath = Test-Path "c:\temp"
     if ($TestPath -eq $false)
        {
           $mkdir = mkdir "c:\temp"
        }
     $WriteFile = Add-Content -Path $LogPath -Value $Trace
}


# Create domain account used for ADFS and WAP deployment
if ($deployADFSWAPDeploymentAccount -eq "Yes")
{
								
		$error.Clear()
				
		try
		{
			# Create ADFS and WAP deployment account
			New-ADUser -name $adfswapdeploymentaccount -AccountPassword (ConvertTo-SecureString $adfswapdeploymentaccountpwd -AsPlainText -Force) -Enabled 1
			
		}
		catch
		{
			 $Trace = "-"
			 $Action = "ERROR: Unable to create ADFS & WAP deployment account. Account is already exist or error executing the script."
			 $Trace += "$Action `r`n"   
			 $Trace += "Exiting Script."
			 $Trace += "`r`n"
			 $LogPath = "c:\temp\UnableCreateADFSWAPDeploymentSA.log"
			 $TestPath = Test-Path "c:\temp"
			 if ($TestPath -eq $false)
				{
				   $mkdir = mkdir "c:\temp"
				}
			 $WriteFile = Add-Content -Path $LogPath -Value $Trace

		}
		If(!$error)
		{
			 $Trace = "-"
			 $Action = "INFORMATION: Created the ADFS & WAP Deployment account"
			 $Trace += "$Action `r`n"   
			 $Trace += "Exiting Script."
			 $Trace += "`r`n"
			 $LogPath = "c:\temp\CreateADFSWAPDeploymentSA.log"
			 $TestPath = Test-Path "c:\temp"
			 if ($TestPath -eq $false)
				{
				   $mkdir = mkdir "c:\temp"
				}
			 $WriteFile = Add-Content -Path $LogPath -Value $Trace

		}

}
else
{
	 $Trace = "-"
	 $Action = "Deployment of the ADFS & WAP deployment account is not performed"
     $Trace += "$Action `r`n"   
     $Trace += "Exiting Script."
     $Trace += "`r`n"
     $LogPath = "c:\temp\SkipDeployADFSWAPDeploymentSA.log"
     $TestPath = Test-Path "c:\temp"
     if ($TestPath -eq $false)
        {
           $mkdir = mkdir "c:\temp"
        }
     $WriteFile = Add-Content -Path $LogPath -Value $Trace
}


# Replicate DCs
repadmin /syncall

# Set DFSR on DC1 to 1
$obj = Get-ADObject -Identity "CN=SYSVOL Subscription,CN=Domain System Volume,CN=DFSR-LocalSettings,CN=$DCvmName,OU=Domain Controllers,$domainFQDN" -Properties "msDFSR-Options"
$obj.'msDFSR-Options' = 1
Set-ADObject -Instance $obj


#end


                
