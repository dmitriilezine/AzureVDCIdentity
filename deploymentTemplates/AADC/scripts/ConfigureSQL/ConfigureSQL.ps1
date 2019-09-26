
configuration ConfigureSQL
{ 
   param 
   ( 
      		
        [Int]$RetryCount=20,
        [Int]$RetryIntervalSec=30,
		[string]$computerName
    ) 
    
    Import-DscResource -ModuleName xStorage, PSDesiredStateConfiguration

	$dnGdrive = (Get-Partition | where-object -filterscript { $_.DriveLetter -eq "G" }).DiskNumber
    if (!$dnGdrive) { $dnGdrive = 3 }
	

    Node localhost
    {
		
		xWaitforDisk Disk3
        {
             DiskId = $dnGdrive
             RetryIntervalSec =$RetryIntervalSec
             RetryCount = $RetryCount
        }

        xDisk DataVolumeDisk3
        {
             DiskId = $dnGdrive
             DriveLetter = 'G'
             FSLabel = 'SQLVMLOG1' 
             DependsOn = '[xWaitForDisk]Disk3'
        }

		Script RebootComputer
		{
			SetScript =
			{
				
				Restart-Computer -ComputerName $using:computerName -Force
			}

            TestScript = { return Test-Path "G:\" } 
            GetScript = { @{} }
            DependsOn  = '[xDisk]DataVolumeDisk3'
		}


        Script ConfigureSQLviaScript
        {
            SetScript = 
            { 
                
$Trace = @()
$Error.Clear()
$Action = "Beginning Post Build PowerShell Operations on VM."
$Trace += "$Action `r`n" 
Try
{
		Start-Sleep -s 60    
	
        # Making G:\Log Directory    
        $Action = "Now Making Directory G:\Log."
        $Trace += "$Action `r`n" 

			$mkdir = mkdir "G:\Log"    
		
      
        # Stopping Services
        $Action = "Stopping SQL Server Agent Service and SQL Server Service."
        $Trace += "$Action `r`n"  
        $Stop = Stop-Service "SQLSERVERAGENT" -Force  
        $Stop = Stop-Service "MSSQLSERVER" -Force
        
        # Starting SQL Server in Single-User mode
        $Action = "Starting SQL Server Service in Single-User Mode."
        $Trace += "$Action `r`n"   
        $start = net start mssqlserver /mSQLCMD
        
        # Granting Admins SA Rights
        $Action = "Giving Administrators Group SQL SA rights."
        $Trace += "$Action `r`n"   
        $sqlcmd = sqlcmd -Q "if not exists(select * from sys.server_principals where name='BUILTIN\administrators') CREATE LOGIN [BUILTIN\administrators] FROM WINDOWS;EXEC master..sp_addsrvrolemember @loginame = N'BUILTIN\administrators', @rolename = N'sysadmin'" 

        # Restarting SQL into multi-user Mode and testing rights
        $Action = "Stopping and Restarting SQL Server Service in Multi-User Mode. Testing if SA rights are given for current login."
        $Trace += "$Action `r`n" 
        $Stop = net stop mssqlserver 
        $Start = Start-Service "MSSQLSERVER" 
        $Sqlcmd = sqlcmd -Q "if exists( select * from fn_my_permissions(NULL, 'SERVER') where permission_name = 'CONTROL SERVER') print 'Current login is a sysadmin!'"
        $Trace += "$Sqlcmd`r`n"

        # Import-Module SQLPS
        $Action = "Importing SQLPS Module."
        $Trace += "$Action `r`n"  
        $Import = Import-Module SQLPS -Force
        $Sleep = Start-Sleep -s 45
        
        # Setting Log Directory Variables
        $Action = "Setting Log Directory Variables."
        $Trace += "$Action `r`n" 
        $NewLog = 'G:\log\tempdb.ldf'
        $TempLog = "N'" + $NewLog + "'" # This format is needed for Invoke-SQLCMD

        # Perform TempDB Log File move to G:\Log directory
        $Action =  "Modifying TempLog location using Invoke-SQLCMD."
        $Trace += "$Action `r`n" 
        $Invoke = Invoke-SQLCMD -Query "USE [master]" 
        $Sleep = Start-Sleep -s 5
        $Invoke = Invoke-SQLCMD -Query "ALTER DATABASE TempDB MODIFY FILE (NAME = templog, FILENAME = $TempLog) " 
        $Sleep = Start-Sleep -s 10            
        
        # Stop SQL Server Service
        $Action = "Stopping SQL Server Service."
        $Trace += "$Action `r`n" 
        $Stop = Stop-Service "MSSQLSERVER" -Force
        $Sleep = Start-Sleep -s 30
        
        # Perform Default Log Directory move to G:\Log directory
        $Action =  "Modifying Default Log Folder Location."
        $Trace += "$Action `r`n" 
        #$RegistryPath = "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL13.MSSQLSERVER\MSSQLServer"
		$RegistryPath = "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL14.MSSQLSERVER\MSSQLServer"
        $GetPath = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL14.MSSQLSERVER\MSSQLServer" -Name "DefaultLog"
        if ($GetPath -ne $null)
        {
            Set-ItemProperty -Path $RegistryPath -Name "DefaultLog" -Value "G:\Log"
        }
        Else
        {
            $Action = "Registry Path '$RegistryPath' does not exist. Exiting Script."
            $Trace += "$Action `r`n" 
            throw
        }

        # Starting SQL Server in Single-User mode
        $Action = "Starting SQL Server Service in Single User Mode."
        $Trace += "$Action `r`n"   
        $Start = net start mssqlserver /mSQLCMD
        
        # Removing SA Rights from Administrators for security cleanup
        $Action = "Removing Administrators Group SQL SA rights"
        $Trace += "$Action `r`n"   
        $sqlcmd = sqlcmd -Q "if exists(select * from sys.server_principals where name='BUILTIN\administrators') DROP LOGIN [BUILTIN\administrators]" 

        # Restarting SQL into multi-user Mode and testing rights
        $Action = "Stopping and Restarting SQL Server Service in Multi-User Mode. Testing if SA rights are removed for current login."
        $Trace += "$Action `r`n" 
        $Stop = net stop mssqlserver 
        $Start = Start-Service "MSSQLSERVER" 
        $Sqlcmd = sqlcmd -Q "if not exists( select * from fn_my_permissions(NULL, 'SERVER') where permission_name = 'CONTROL SERVER') print 'Sysadmin Rights Removed!'"
        $Trace += "$Sqlcmd`r`n"
        
        # Remove F:\Log Directory
        $Action = "Removing F:\Log Directory."
        $Trace += "$Action `r`n" 
        $RM = Remove-Item "F:\Log" -Recurse -Force

    <#
    # Import Modules and Install Windows Updates    
    $Action = "Installing PackageProvider NuGet."
    $Trace += "$Action `r`n" 
    $InstallPkgProv = Install-PackageProvider -Name NuGet -confirm:$false -Force

    $Action = "Installing Module PSWindowsUpdate."
    $Trace += "$Action `r`n" 
    $InstallModule = Install-Module PSWindowsUpdate -Confirm:$false -Force

    $Action = "Register the Microsoft Update Service for use."
    $Trace += "$Action `r`n" 
    $AddWUSvcMgr = Add-WUServiceManager -ServiceID 7971f918-a847-4430-9279-4a52d1efe18d -Confirm:$false

    $Action = "Find, Download, and Install Windows Updates, then Reboot."
    $Trace += "$Action `r`n" 
    $InstallUpdates = Get-WUInstall –MicrosoftUpdate –AcceptAll -Install –AutoReboot #>
}
Catch
{
    $Trace += "Exception caught in action '$Action'... `r`n"
    $ErrorState = 2
    $ErrorMessage = $error[0].Exception.tostring()
}
Finally
{
    $Trace += "Exiting Script."
    $Trace += "`r`n"
    $LogPath = "c:\temp\PostBuildLog.log"
    $TestPath = Test-Path "c:\temp"
    if ($TestPath -eq $false)
    {
        $mkdir = mkdir "c:\temp"
    }
    $WriteFile = Add-Content -Path $LogPath -Value $Trace
}

            }
            TestScript = { Test-Path "G:\log\tempdb.ldf" }
            GetScript = { @{} }
            DependsOn  = '[Script]RebootComputer'
                      
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


