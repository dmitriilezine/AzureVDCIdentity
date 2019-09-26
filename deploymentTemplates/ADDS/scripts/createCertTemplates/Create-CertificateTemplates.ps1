


#####################################
# Initialize current environment variables
#####################################
#Set-Location $ScriptPath # Set the working location of the script to the path of the script
$RootDse = [ADSI]"LDAP://RootDSE"; $DomainDN = $RootDse.Get("rootDomainNamingContext") # Get the DN of the domain
$TargetDC = Get-ADDomainController -Discover -Service "PrimaryDC" # Get the PDC emulator as the target DC

# Folders
$scripts = "c:\ExtendAD\ADCSscripts"


$LogFile = ("Transcript-{0:yyyy-MM-dd-HH-mm-ss}.log" -f (Get-Date)) 
$Log = "$scripts\$LogFile" 
Start-Transcript $Log

# Wait 15 seconds
Start-Sleep -Seconds 30

$WorkstationTemplate = "CN=Workstation,CN=Certificate Templates,CN=Public Key Services,CN=Services,CN=Configuration,"+$DomainDN
$SmartCardLogonTemplate = "CN=SmartCardLogon,CN=Certificate Templates,CN=Public Key Services,CN=Services,CN=Configuration,"+$DomainDN
$KerberosTemplate = "CN=KerberosAuthentication,CN=Certificate Templates,CN=Public Key Services,CN=Services,CN=Configuration,"+$DomainDN
$AdministratorTemplate = "CN=Administrator,CN=Certificate Templates,CN=Public Key Services,CN=Services,CN=Configuration,"+$DomainDN
$group = Get-ADGroup "Domain Computers"
$DomainComputersSID = new-object System.Security.Principal.SecurityIdentifier $group.SID
$group = Get-ADGroup "Domain Controllers"
$DomainControllersSID = new-object System.Security.Principal.SecurityIdentifier $group.SID


#####################################
# Import required Powershell modules
#####################################
Import-Module ActiveDirectory

#####################################
# Functions 
#####################################

function Import-CaTemplate([string]$TemplateName, [string]$Path)
{
ldifde.exe -i -f $Path -c "DC=domain,DC=com" $DomainDN
}


function CopyRights([string]$SourceTemplate, [string]$DestinationTemplate)
{
    cd ad:    
    $acl = Get-Acl $SourceTemplate
    set-acl -aclobject $acl $DestinationTemplate
}

function AddEnrollRight([string]$Template, $Actor)
{
    $CertificateEnrollmentRight = [system.guid]"0e10c968-78fb-11d2-90d4-00c04f79dc55"
    $ace = new-object System.DirectoryServices.ActiveDirectoryAccessRule $Actor,"ExtendedRight","Allow",$CertificateEnrollmentRight,"All"
    cd ad:
    $acl = Get-Acl $Template
    $acl.AddAccessRule($ace)
    set-acl -aclobject $acl $Template
}

function AddAutoEnrollRight([string]$Template, $Actor)
{
    $CertificateAutoEnrollmentRight = [system.guid]"a05b8cc2-17bc-4802-a710-e7c15ab866a2" 
    $ace = new-object System.DirectoryServices.ActiveDirectoryAccessRule $Actor,"ExtendedRight","Allow",$CertificateAutoEnrollmentRight,"All"
    cd ad:
    $acl = Get-Acl $Template
    $acl.AddAccessRule($ace)
    set-acl -aclobject $acl $Template
}

#####################################
# Import Certificate Templates
#####################################

####### Online IPsec Template #######
## Write-Host "Importing '$IPsecTemplate' Certificate Template" -Fore Cyan
$template = "CN=AzurePAW Online IPsec,CN=Certificate Templates,CN=Public Key Services,CN=Services,CN=Configuration,"+$DomainDN
$sTemplate = Join-path $scripts -childpath "\CertificateTemplates\OnlineIPsec.ldf"
Import-CaTemplate $template $sTemplate
# Workstation Template + Domain Computer and Domain Controller Enroll and AutoEnroll
CopyRights $WorkstationTemplate $template
AddEnrollRight $template $DomainComputersSID
AddEnrollRight $template $DomainControllersSID
AddAutoEnrollRight $template $DomainComputersSID
AddAutoEnrollRight $template $DomainControllersSID

####### Kerberos Template #######
$template = "CN=AzurePAW Kerberos,CN=Certificate Templates,CN=Public Key Services,CN=Services,CN=Configuration,"+$DomainDN
$sTemplate = Join-path $scripts -childpath "\CertificateTemplates\Kerberos.ldf"
Import-CaTemplate $template $sTemplate
CopyRights $KerberosTemplate $template

####### Smart Card Logon Template #######
$template = "CN=AzurePAW SmartCard Logon,CN=Certificate Templates,CN=Public Key Services,CN=Services,CN=Configuration,"+$DomainDN
$sTemplate = Join-path $scripts -childpath "\CertificateTemplates\SmartCardLogon.ldf"
Import-CaTemplate $template $sTemplate
CopyRights $SmartCardLogonTemplate $template

####### Interforest IPsec Template #######
$template = "CN=AzurePAW Offline IPsec,CN=Certificate Templates,CN=Public Key Services,CN=Services,CN=Configuration,"+$DomainDN
$sTemplate = Join-path $scripts -childpath "\CertificateTemplates\OfflineIPsec.ldf"
Import-CaTemplate $template $sTemplate
CopyRights $WorkstationTemplate $template

####### SCOM GW Auth Template #######
$template = "CN=AzurePAW SCOM GW,CN=Certificate Templates,CN=Public Key Services,CN=Services,CN=Configuration,"+$DomainDN
$sTemplate = Join-path $scripts -childpath "\CertificateTemplates\SCOMGW.ldf"
Import-CaTemplate $template $sTemplate
CopyRights $WorkstationTemplate $template

####### Web Server Template #######
$template = "CN=AzurePAW Web Server,CN=Certificate Templates,CN=Public Key Services,CN=Services,CN=Configuration,"+$DomainDN
$sTemplate = Join-path $scripts -childpath "\CertificateTemplates\AzurePAWWebServer.ldf"
Import-CaTemplate $template $sTemplate
AddEnrollRight $template $DomainComputersSID

####### HGS Server Template #######
$template = "CN=AzurePAW HGS,CN=Certificate Templates,CN=Public Key Services,CN=Services,CN=Configuration,"+$DomainDN
$sTemplate = Join-path $scripts -childpath "\CertificateTemplates\azurepawhgs.ldf"
Import-CaTemplate $template $sTemplate
AddEnrollRight $template $DomainComputersSID
CopyRights $WorkstationTemplate $template

####### VPN User Template #######
$template = "CN=AzurePAW VPN,CN=Certificate Templates,CN=Public Key Services,CN=Services,CN=Configuration,"+$DomainDN
$sTemplate = Join-path $scripts -childpath "\CertificateTemplates\azurepawvpn.ldf"
Import-CaTemplate $template $sTemplate
CopyRights $AdministratorTemplate $template


### Force Replication to get templates on DC2
repadmin /syncall
Start-Sleep -s 30

cd $scripts

Stop-Transcript