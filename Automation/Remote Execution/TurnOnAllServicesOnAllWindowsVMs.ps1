###########################################################
#-- Script: TurnOnAllServicesOnAllWindowsVMs.ps1
#-- Created: 5/19/2020
#-- Author: Ben Lucas, Atlas Technologies Technologies
#-- Description: 
#-- >Prompts user for Default Password
#-- >Checks to see which automatic services are off 
#-- >Attempts to turn them on.
#-- >Asks user if they want to run script again
#-- Needs to be set:
#-- Line 63-66 -> Set admin credential names, all accounts should have Default password
#-- Line 69-74 -> Connection IPs to ESX hosts, enter one for each server
#-- Line 87 -> VMName to DNS Name Conversion string
#-- History: Created in May 2020 by Ben Lucas
#-- SSA         1.0.0.0 5/19/2020
###########################################################
#region: elevate command
# Get the ID and security principal of the current user account
$myWindowsID = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$myWindowsPrincipal = new-object System.Security.Principal.WindowsPrincipal($myWindowsID)

# Get the security principal for the Administrator role
$adminRole = [System.Security.Principal.WindowsBuiltInRole]::Administrator

# Check to see if we are currently running "as Administrator"
if ($myWindowsPrincipal.IsInRole($adminRole))
{
	# We are running "as Administrator" - so change the title and background color to indicate this
	$Host.UI.RawUI.WindowTitle = $myInvocation.MyCommand.Definition + "(Elevated)"
	#$Host.UI.RawUI.BackgroundColor = "DarkBlue"
	#clear-host
}
else
{
	# We are not running "as Administrator" - so relaunch as administrator
	Start-Process "$psHome\powershell.exe" -Verb Runas -ArgumentList "-File `"$($myInvocation.MyCommand.Definition)`""
	
	# Exit from the current, unelevated, process
	Exit
}
#endregion

Add-Type -AssemblyName System.Windows.Forms

#Get Start time
$ScriptStartTime = (Get-Date)
$BackupDate = (Get-Date -format ddMMMyyyy)
Write-Host The current time is $ScriptStartTime

#Load the VMWare PowerCLI SnapIn so that PowerCLI commandlets can be used
import-module vmware.vimautomation.core

#Deal with Logfile creation/clearing
$logFile = ".\ServiceStatusResults.txt" #file Path must exists
if(!(Test-Path $logFile)){
    $global:servicesListtatusResults = New-Item -Path ".\" -Name "ServiceStatusResults.txt" -ItemType "file"
    write-host ("Log file didn't exist, I created a new one here->: "+$global:servicesListtatusResults.Fullname)
}else{
    Set-Content $logFile -Value ""
    write-host ("Old Log data erased, I am saving results here->: "+$logFile)
}
# Get needed credentials
$global:DAUser = Get-Credential -Credential "<domain>\<domain admin>" #domain admin
$global:rtUser = New-Object System.Management.Automation.PSCredential ("<esx admin>",$global:DAUser.Password) #esx admin
$global:WAUser = New-Object System.Management.Automation.PSCredential ("<domain>\<workstation admin>",$global:DAUser.Password) #workstation admin
$global:SAUser = New-Object System.Management.Automation.PSCredential ("<domain>\<server admin>",$global:DAUser.Password) #server admin
$global:cred = ""
# ESX IPs
$ESX01Address = '<IP Address of ESX Host>'
#$ESX02Address = '<IP Address of ESX Host>'
#$ESX03Address = '<IP Address of ESX Host>'
#$ESX04Address = '<IP Address of ESX Host>'
#$ESX05Address = '<IP Address of ESX Host>'
#$ESX06Address = '<IP Address of ESX Host>'
#List objects
$global:servicesList = @()
[HashTable]$global:servicesHashList = @{}
$VMs= @()

# Name Partial Name Removal String Variable->This string will be removed from the computer name for proper script functioning
# If you the VM name and the Windows DNS name differ, this string is used to take away extra data in the ESX VM name 
# for the machine. EXAMPLE:
# VM Name is "MyDomain_WKS101"
# DNS Name is "WKS101"
# You would enter this to remove the extra data:
# $removeThisStringFromVMName = "MyDomain_"
$removeThisStringFromVMName = ""

#Connect to an ESX host
#Modify the below to fit your needs. One at a time. may want to manually migrate all machines to ESX01 if multiple hosts
try{
    Connect-VIServer -Server $ESX01Address -Credential $global:rtUser -ErrorAction SilentlyContinue
    #Connect-VIServer -Server $ESX02Address -Credential $global:rtUser -ErrorAction SilentlyContinue
    #Connect-VIServer -Server $ESX03Address -Credential $global:rtUser -ErrorAction SilentlyContinue
    #Connect-VIServer -Server $ESX04Address -Credential $global:rtUser -ErrorAction SilentlyContinue
    #Connect-VIServer -Server $ESX05Address -Credential $global:rtUser -ErrorAction SilentlyContinue
    #Connect-VIServer -Server $ESX06Address -Credential $global:rtUser -ErrorAction SilentlyContinue
    if($? -eq $false){throw $error[0].exception}   
}catch [Exception]{
    Read-Host "Wrong Credentials for ESX host. Hit enter to exit..." 
    exit
}

#Gathers Data about which services are off on a single machine
function Check-AutomaticServices{
        param (
        [Parameter(Mandatory=$true)]
        $MachineName,      
        $singleService = ""     
    )
    $Global:VM = Get-VM | Where-object {$_.name -like ("*"+$MachineName)} 
    if($Global:VM.PowerState -like "PoweredOn"){
        $VMName = $MachineName -replace $removeThisStringFromVMName,""
        if($Global:VM.GuestId -like "*Window*"){
            $global:cred = $global:SAUser# default is server admin
            if($VM.Name -like "*<DomainControllerNamingConvention>*"){
                $global:cred = $global:DAUser
            }
            if($VM.Name -like "*<WorkstationNamingConvention>*"){
                $global:cred = $global:WAUser
            }     
            if($singleService -eq ""){
                #We have to ignore four services that are off always on all VMs, unless needed (CDPSvc,sppsvc,ScarSvr,RemoteRegistry)
                if($env:COMPUTERNAME -eq $VMName){#Check for computer that script is being run from to handle differently
                    $global:servicesList = Get-WmiObject -ComputerName $VMName -Query "select * from win32_service where StartMode='Auto' AND State<>'Running' AND name<>'CDPSvc' AND name<>'sppsvc' AND name<>'SCardSvr' AND name<>'RemoteRegistry'"
                }else{
                    $global:servicesList = Get-WmiObject -ComputerName $VMName -Query "select * from win32_service where StartMode='Auto' AND State<>'Running' AND name<>'CDPSvc' AND name<>'sppsvc' AND name<>'SCardSvr' AND name<>'RemoteRegistry'" -Credential $global:cred                
                }
            }else{
                $global:servicesList = Get-WmiObject -ComputerName $VMName -Query "select * from win32_service where name='$singleService'" -Credential $global:cred
            }
            
            foreach($svc in $global:servicesList){
                $svcName = $svc.DisplayName
                write-host ("---------------------")
                write-host ("Found:"+$svcName) -ForegroundColor Magenta
                write-host ("VM:" +$VMName) -ForegroundColor Magenta
                write-host ("Service State: "+$svc.state) -ForegroundColor Yellow
                if($global:servicesHashList.Contains($svcName)){
                    $key = $svcName
                    $global:servicesHashList.$key += @($VMName)       
                }else{
                    $global:servicesHashList.add($svcName,@($VMName))
                }
            }
        }else{
                Write-Host "This machine ($VMName) does not have Windows OS" -ForegroundColor Yellow
        }    
    }
}

#Gathers data about which services are off on a single machine and turns turns them on 
function Start-AllServices{
        param (
        [Parameter(Mandatory=$true)]
        $MachineName,      
        $singleService = ""     
    )
    $Global:VM = Get-VM | Where-object {$_.name -like ("*"+$MachineName)} 
    if($Global:VM.PowerState -like "PoweredOn"){
        $VMName = $MachineName -replace $removeThisStringFromVMName,""
        if($Global:VM.GuestId -like "*Window*"){
            $global:cred = $global:SAUser# default is server admin
            if($VM.Name -like "*<DomainControllerNamingConvention>*"){
                $global:cred = $global:DAUser
            }
            if($VM.Name -like "*<WorkstationNamingConvention>*"){
                $global:cred = $global:WAUser
            }     
            if($singleService -eq ""){
                #We have to ignore four services that are off always on all VMs, unless needed (CDPSvc,sppsvc,ScarSvr,RemoteRegistry)
                if($env:COMPUTERNAME -eq $VMName){#Check for computer that script is being run from to handle differently
                    $global:servicesList = Get-WmiObject -ComputerName $VMName -Query "select * from win32_service where StartMode='Auto' AND State<>'Running' AND name<>'CDPSvc' AND name<>'sppsvc' AND name<>'SCardSvr' AND name<>'RemoteRegistry'"
                }else{
                    $global:servicesList = Get-WmiObject -ComputerName $VMName -Query "select * from win32_service where StartMode='Auto' AND State<>'Running' AND name<>'CDPSvc' AND name<>'sppsvc' AND name<>'SCardSvr' AND name<>'RemoteRegistry'" -Credential $global:cred                
                }
            }else{
                $global:servicesList = Get-WmiObject -ComputerName $VMName -Query "select * from win32_service where name='$singleService'" -Credential $global:cred
            }            
            foreach($svc in $global:servicesList){
                $svcName = $svc.DisplayName
                try{
                    $result = $svc.StartService() 
                    $result = $svc.StartService().ReturnValue 
                    if($result -eq 10){
                        Write-Host "-----------------------------------------"
                        Write-Host ""
                        Write-Host "$svcName 0n $VMName Start Code(10 = Running): $result" -ForegroundColor Green
                        Write-Host "Give it a second to start..."
                        Start-Sleep 1                    
                        
                        Add-Content $logFile "-----------------------------------------"
                        Add-Content $logFile ""
                        Add-Content $logFile "$svcName 0n $VMName Start Code(10 = Running): $result" 
                        Add-Content $logFile "Give it a second to start..."
                    }else{
                        Write-Host "-----------------------------------------"
                        Write-Host "" 
                        Write-Host "$svcName 0n $VMName Didn't Start Properly" -ForegroundColor Red
                        
                        Add-Content $logFile "-----------------------------------------"
                        Add-Content $logFile "" 
                        Add-Content $logFile "$svcName 0n $VMName Didn't Start Properly" 
                    }
                }catch{
                    Write-Host "Something is Amiss!" -ForegroundColor Red
                    Write-Host $PSItem -ForegroundColor Red
                    
                    Add-Content $logFile "Something is Amiss!" 
                    Add-Content $logFile $PSItem
                }    
            }
        }else{
                Write-Host "This machine ($VMName) does not have Windows OS" -ForegroundColor Yellow
        }    
    }
}

#Get-VM that are windows boxes
$VMs = Get-VM | Where-object {$_.GuestId -like "*Windows*"}
#Check services on each VM
foreach ($VM in $VMs){
    $VMName = $VM.Name -replace $removeThisStringFromVMName,""
    if($VM.PowerState -eq "PoweredOn"){
        Check-AutomaticServices -MachineName $VMName
    }else{
        Write-Host ("VM:"+$VM.name+" is Off!") -ForegroundColor Yellow
    }
}
Write-Host ">>--------------TABULATION COMPLETE!--------------<<" -ForegroundColor Yellow
Write-Host "<<----Listing Stopped Services Alphabetically----->>" -ForegroundColor Yellow

Add-Content $logFile "--------->Service Status Report---------------------------------------->"
Add-Content $logFile "Last Run:$ScriptStartTime"

$results = $global:servicesHashList.GetEnumerator() | sort name

# Log and report results
forEach($pair in $results){
    write-host "-----------------------------------------"
    Add-Content $logFile "-----------------------------------------"
    foreach($value in $pair.Value){
        write-host ($pair[0].Key+"-->"+$value) -ForegroundColor red
        Add-Content $logFile ($pair[0].Key+"-->"+$value)   
    }
}

#Read user input for starting services
$answer=Read-host "Would you like to attempt to start the services?[y to proceed, any other to quit]"
if($answer.ToUpper() -eq 'Y'){
    Write-host "!-----------------------------------------!" 
    Write-host "<----------!Turning On Services!---------->" -ForegroundColor Green
    Write-host "!-----------------------------------------!" 
    Write-host "" 
    Add-Content $logFile "!-----------------------------------------!" 
    Add-Content $logFile "<----------!Turning On Services!---------->" 
    Add-Content $logFile "!-----------------------------------------!"
    Add-Content $logFile "" 
    foreach ($VM in $VMs){
        $VMName = $VM.Name -replace $removeThisStringFromVMName,""
        if($VM.PowerState -eq "PoweredOn"){
            Start-AllServices -MachineName $VMName
        }else{
            Write-Host ("VM:"+$VM.name+" is Off!") -ForegroundColor Yellow
        }
    }
}
# open results file for viewing
Write-host "!-----------------------------------------!" 
Write-host "<------------!Finished Script!------------>" -ForegroundColor Green
Write-host "!-----------------------------------------!" 
Add-Content $logFile "!-----------------------------------------!" 
Add-Content $logFile "<------------!Finished Script!------------>" 
Add-Content $logFile "!-----------------------------------------!" 

Invoke-Item $logFile

write-host "-----------------------------------------------------------------------------------------------------------"
write-host "Some Services may now be able to start due to other services that were just started.  Some services 
can shut off again in a few minutes if there are certain issues.  If this is the first time you ran this script,
you may want to run it again and see if some of the services that remain off will start now that other services 
have started.  Recommended troubleshooting for services that remain off is log onto affected computer and check 
settings and credentials for affected services."
write-host "-----------------------------------------------------------------------------------------------------------"
# read user input to rerun script if necessary
$runAgain = read-Host "Would you like to rerun this script?[y to proceed, any other to quit]"
if($runAgain.ToUpper() -eq 'Y'){
	# We are not running "as Administrator" - so relaunch as administrator
	Start-Process "$psHome\powershell.exe" -Verb Runas -ArgumentList "-File `"$($myInvocation.MyCommand.Definition)`""
}
Disconnect-VIServer -Server $ESX01Address -confirm:$false
#Disconnect-VIServer -Server $ESX02Address -confirm:$false
#Disconnect-VIServer -Server $ESX03Address -confirm:$false
#Disconnect-VIServer -Server $ESX04Address -confirm:$false
#Disconnect-VIServer -Server $ESX05Address -confirm:$false
#Disconnect-VIServer -Server $ESX06Address -confirm:$false