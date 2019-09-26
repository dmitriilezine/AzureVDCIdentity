configuration InstallADCS 
{ 
   param 
   ( 
        [Parameter(Mandatory)]
        [String]$DomainName,

        [Parameter(Mandatory)]
        [String]$CACommonName,

        [Parameter(Mandatory)]
        [String]$shortDomainName,

        [Parameter(Mandatory)]
        [String]$DSDomainDN,

        [Parameter(Mandatory)]
        [String]$CAName,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$Admincreds,
		
        [Int]$RetryCount=20,
        [Int]$RetryIntervalSec=30
    ) 
    
    $DSConfigDN = "CN=Configuration,"+$DSDomainDN
    $ValPer_Units = "5"
    $CRLPer_Units = "30"
    $CRL = $shortDomainName+"-CA.crl"
    $AIA = $shortDomainName+"-CA.crt"
    $IPsecTemplate = "AzurePAW Online IPsec"    $KerbAuthTemplate = "AzurePAW Kerberos"    $SCLogonTemplate = "AzurePAW SmartCard Logon"    $IntForIPsecTemplate = "AzurePAW Offline IPsec"    $SCOMGWTemplate = "AzurePAW SCOM GW"
    $WebServerTemplate = "AzurePAW Web Server"
    $HGSTemplate = "AzurePAW HGS"
    $VPNTemplate = "AzurePAW VPN"
    $logdir = "c:\InstallCALogs"

    Import-DscResource -ModuleName xAdcsDeployment,PSDesiredStateConfiguration
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

        WindowsFeature ADCS-Cert-Authority
        {
            Ensure = 'Present'
            Name = 'ADCS-Cert-Authority'
            DependsOn  = '[Script]CreateCAPolicyINFfile'
        }

        WindowsFeature RSAT-ADCS-Mgmt
        {
            Ensure = 'Present'
            Name = 'RSAT-ADCS-Mgmt'
        }

        xAdcsCertificationAuthority CertificateAuthority
        {
            Ensure     = 'Present'
            Credential = $DomainCreds
            CAType     = 'EnterpriseRootCA'
            CACommonName = $CACommonName
            CADistinguishedNameSuffix = $DSDomainDN
            CryptoProviderName = "RSA#Microsoft Software Key Storage Provider"
            HashAlgorithmName = "SHA256"
            KeyLength = "2048"
            ValidityPeriod = "Years"
            ValidityPeriodUnits = "5"
            DependsOn  = '[WindowsFeature]ADCS-Cert-Authority'
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
            TestScript = { Test-Path "c:\InstallCALogs\Test.log" }
            GetScript = { @{} }          
        }
        
        
        Script CreateCAPolicyINFfile
        {
            SetScript = 
            { 
                $sw = New-Object System.IO.StreamWriter("c:\windows\capolicy.inf")
                $sw.WriteLine("[Version]")
                $sw.WriteLine('Signature = "$Windows NT$"')
                $sw.WriteLine("[PolicyStatementExtension]")
                $sw.WriteLine("Policies = AllIssuancePolicy")
                $sw.WriteLine("[Certsrv_Server]")
                $sw.WriteLine("RenewalKeyLength=2048")
                $sw.WriteLine("RenewalValidityPeriodUnits=Years")
                $sw.WriteLine("RenewalValidityPeriod=5")
                $sw.WriteLine("LoadDefaultTemplates = 0")
                $sw.WriteLine("CRLPeriod=days")
                $sw.WriteLine("CRLPeriodUnits=180")
                $sw.WriteLine("CRLDeltaPeriod=hours")
                $sw.WriteLine("CRLDeltaPeriodUnits=0")
                $sw.WriteLine("CRLOverlapPeriod=Days")
                $sw.WriteLine("CRLOverlapUnits=2")
                $sw.WriteLine("CRLDeltaOverlapPeriod=Days")
                $sw.WriteLine("CRLDeltaOverlapUnits=3")
                $sw.WriteLine("[CRLDistributionPoint]")
                $sw.WriteLine("Empty=True")
                $sw.WriteLine("[AuthorityInformationAccess]")
                $sw.WriteLine("Empty=True")
                $sw.Close()
            }
            TestScript = { Test-Path "c:\windows\capolicy.inf" }
            GetScript = { @{} }          
        }

        Script PostCAConfiguration
        {
            SetScript = 
            { 
                $LogFile = ("PostCAConfiguration-{0:yyyy-MM-dd-HH-mm-ss}.log" -f (Get-Date)) 
                $Log = "$using:logdir\$LogFile" 
                Start-Transcript $Log
                
                certutil -setreg CA\DSConfigDN " $using:DSConfigDN "
                certutil -setreg CA\CRLPeriodUnits $using:CRLPer_Units
                certutil -setreg CA\CRLPeriod "Days"
                certutil -setreg CA\CRLDeltaPeriodUnits 0
                certutil -setreg CA\CRLDeltaPeriod "Days"
                certutil -setreg CA\CRLPublicationURLs "1:c:\windows\system32\CertSrv\CertEnroll\%3%8%9.crl\n1:c:\windows\system32\CertSrv\CertEnroll\$using:CRL\n15:ldap:///CN=%7%8,CN=%2,CN=CDP,CN=Public Key Services,CN=Services,%6%10\n"
                certutil -setreg CA\CACertPublicationURLs "1:c:\windows\system32\CertSrv\CertEnroll\%3.crt\n1:c:\windows\system32\CertSrv\CertEnroll\$using:AIA\n3:ldap:///CN=%7,CN=AIA,CN=Public Key Services,CN=Services,%6%11\n"
                certutil -setreg CA\AuditFilter 127
                certutil -setreg CA\ValidityPeriodUnits $using:ValPer_Units
                certutil -setreg CA\ValidityPeriod "Years"
                Certutil -setreg ca\CRLFlags +CRLF_REVCHECK_IGNORE_OFFLINE
                Certutil -setreg ca\interfaceflags +0x8
                Restart-Service certsvc
                Start-Sleep -s 20

                Stop-Transcript
            }
            TestScript = { return $false }
            GetScript = { @{} }
            DependsOn  = '[xAdcsCertificationAuthority]CertificateAuthority'
			PsDscRunAsCredential = $DomainCreds
        }

        Script PushCRL
        {
            SetScript = 
            { 
                $LogFile = ("PushCRL-{0:yyyy-MM-dd-HH-mm-ss}.log" -f (Get-Date)) 
                $Log = "$using:logdir\$LogFile" 
                Start-Transcript $Log
                
                certutil -CRL

                Stop-Transcript
            }
            TestScript = { return $false }
            GetScript = { @{} }
            DependsOn  = '[Script]PostCAConfiguration'
        }

        Script AssignTemplates
        {
            SetScript = 
            { 
                $LogFile = ("AssignTemplates-{0:yyyy-MM-dd-HH-mm-ss}.log" -f (Get-Date)) 
                $Log = "$using:logdir\$LogFile" 
                Start-Transcript $Log                                Add-CaTemplate -Name $using:KerbAuthTemplate -confirm:$false                Add-CaTemplate -Name $using:SCLogonTemplate -confirm:$false                Add-CaTemplate -Name $using:IntForIPsecTemplate -confirm:$false                Add-CaTemplate -Name $using:SCOMGWTemplate -confirm:$false                Add-CaTemplate -Name $using:IPsecTemplate -confirm:$false                Add-CaTemplate -Name $using:WebServerTemplate -confirm:$false                Add-CaTemplate -Name $using:HGSTemplate -confirm:$false                Add-CaTemplate -Name $using:VPNTemplate -confirm:$false                net stop certsvc                net start certsvc
                Start-Sleep -s 20

                Stop-Transcript
            }
            TestScript = { 
            
                try{
                    $ReturnObject = Invoke-Command -ComputerName $using:CAName {Get-CaTemplate} -ErrorAction Stop
                    $ReturnObject = $ReturnObject| ?{$_.Name -eq $using:KerbAuthTemplate}
                }
                catch{
                        write-host "Exception Type: $($_.Exception.GetType().FullName)" -ForegroundColor Red
                }

                If ($ReturnObject -ne $null ) # If the Template already exists in the published certificate templates list on the CA
                    {
                        return $true
                    }    
                Else # If the Template doesn't exist
                    {
                        return $false
                    } 
            }
            GetScript = { @{} }
            DependsOn  = '[Script]PostCAConfiguration'
			PsDscRunAsCredential = $DomainCreds
        }

   }
} 

