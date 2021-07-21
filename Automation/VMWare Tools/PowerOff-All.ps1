###########################################################
#-- Script: PowerOff-All.ps1
#-- Created: 5/12/2020
#-- Author: Ben Lucas
#-- Description: Ensures VMTools is running on Windows machines, then uses PowerCLI to power off machines.
#-- This script leaves out VCSA for Domain Admin use
#-- History: Created by Ben Lucas
#-- BL        1.0.0.0 6/12/2020 Refined error handling for efficiency
###########################################################
Add-Type -AssemblyName System.Windows.Forms

#Get Start time
$ScriptStartTime = (Get-Date)
Write-Host The current time is $ScriptStartTime
$BackupDate = (Get-Date -format ddMMMyyyy)

##Build a list of Hosts.  
$Hosts = @("<list of ESX host names>")

#Load the VMWare PowerCLI SnapIn so that PowerCLI commandlets can be used
$SnapIn = "VMware.VimAutomation.Core"
Import-Module -name $Snapin

###THe below is needed to force connection to use TLS 1.2 
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12


#Connect to an ESX host
#Modify the below to fit your needs. One at a time. may want to manually migrate all machines to ESX01 if multiple hosts
$global:cred = get-credential "<root>"#login name for ESX hosts-would need modification if you needed more than one  

foreach($hostIP in $Hosts){
    try{
        Connect-VIServer -Server $hostIP -user $cred.UserName -Password $cred.GetNetworkCredential().Password -ErrorAction SilentlyContinue
        if($? -eq $false){throw $error[0].exception}   
    }catch [Exception]{
        Read-Host "Wrong Credentials for ESX host. Hit enter to exit..." -
        exit
    }
}

#get needed credentials

#Manually Type password each time this is ran for each user
$DAUser = get-credential "<DAUser>"
$WAUser = get-credential "<WAUser>"
$SAUser = get-credential "<SAUser>"

#Hard Code Password so it doesn't need to be typed
<#$DAUserPwd = ConvertTo-SecureString -String "<Plain Text Password>" -AsPlainText -Force
$SAUserPwd = ConvertTo-SecureString -String "<Plain Text Password>" -AsPlainText -Force
$WAUserPwd = ConvertTo-SecureString -String "<Plain Text Password>" -AsPlainText -Force

$DAUser = New-Object System.Management.Automation.PSCredential ("<DAUser>",$DAUserPwd)
$SAUser = New-Object System.Management.Automation.PSCredential ("<SAUser>",$SAUserPwd)
$WAUser = New-Object System.Management.Automation.PSCredential ("<WAUser>",$WAUserPwd)#>

#If VMTools is not running on the windows machine, you can cause damage by shutting power off abruptly
#this function ensures VMTools is on, on the VM.
function Check-VMTools{
        param (
        [Parameter(Mandatory=$true)]
        $MachineName      
    )
    $Global:VM = Get-VM | Where-object {$_.name -like ("*"+$MachineName)} 
    if($Global:VM.PowerState -like "PoweredOn"){
        $VMName = $MachineName -replace "NCC1031_UNCLASS_",""
        if($Global:VM.GuestId -like "*Windows*"){
            $global:cred = $global:SAUser
            if($VM.Name -like "*<Domain Controller Name common suffix/prefix>*"){
                $global:cred = $global:DAUser
            }
            if($VM.Name -like "*<Workstation name common suffix/prefix>*"){
                $global:cred = $global:WAUser
            }        
            Write-host "Checking VMTools Service on $VMName"
            $service = Get-WmiObject -ComputerName $VMName -Query "select * from win32_service where name='VMTools'" -Credential $global:cred
            if ($service -ne $null){
                write-host ("Service State: "+$service.state)
                if($service.state -ne 'Running'){
                    write-host "VM Tools is not started! I will wake it up then!" -ForegroundColor Red
                    try{
                        $result = $service.StartService()
                        $result = $service.StartService().ReturnValue
                        Write-Host "Service Start Code(10 = Running): $result" -ForegroundColor Green
                        Write-Host "Give it a second to start..."
                        Start-Sleep 1
                    }catch{
                        Write-Host "Something is Amiss!" -ForegroundColor Red
                        Write-Host $PSItem.toString() -ForegroundColor Red
                    }    
                }else{
                    write-host "Service is already started on $VMName! Continuing..." -ForegroundColor Green
                }

            }else{
                Write-Host "Service doesn't exist on $VMName"
            }    
        }else{
                Write-Host "This machine ($VMName) does not have Windows OS"
        }    
    }
}

function PowerOff-Machine{
    param (
        [Parameter(Mandatory=$true)]
        $MachineName,
        [int]$wait = 5,
        [bool]$force = $false       
    )
    $MachineName = ("*"+$MachineName)
    $Global:VM = Get-VM | Where-object {$_.name -like ($MachineName)} 
    if($Global:VM.PowerState -eq "PoweredOn"){
        if($force){
            write-host ("I am forcing " + $Global:VM.name + " to turn off...")
            Stop-VM -vm $Global:VM -confirm:$false | Out-Null
        }else{            
            write-host ("I am asking " + $Global:VM.name + " to turn off...")
            Shutdown-VMGuest -vm $Global:VM -confirm:$false | Out-Null          
        }        
        Write-host ("Waiting for host to shutdown for " + $wait + " seconds....")
        Start-sleep -Seconds $wait    
    }else{
        Write-Host ($Global:VM.name+" is already off!") -ForegroundColor Green
    }
}

###########################
#Power Down Secondaries>Graceful
#Get a list of VMs that will be shut down first, where order is not important
$VMs= @()
$VMs = Get-VM | Where-object {$_.name -notlike '*<Domain Server Suffix/Prefix>*' -and $_.name -notlike '*<Other Vital Servers Suffix/Prefix*'}
Write-host "Preparing to shutdown the following machines: "
forEach ($VM in $VMs){Write-host $VM.Name}
Write-Host "------------------BEGINNING SHUTDOWN SEQUENCE------------------" -foregroundcolor yellow
forEach ($VM in $VMs)
{
  Write-Host "-------------------------------------------"
  Check-VMTools -MachineName $VM.Name
  PowerOff-Machine -MachineName $VM.Name -wait 1 
}

#wait 30 seconds for slow machines to shutdown
Write-host "Waiting for machines to finish turning off"
Start-sleep -Seconds 30

#Power Down Secondaries>Hard Shutdown
#Refresh VMs list and then get first round VMs that are still powered on and do hard shutdown on them
$StillOnVMs = $VMs | Where-Object {$_.PowerState -like 'PoweredOn' -and $_.name -notlike '*PFSense'}
forEach ($VM in $StillOnVMs){Write-host $VM.Name}
if($StillOnVMs.Count -gt 0){
    $continueWithShutdown = Read-host "Some hosts aren't shut down yet.  Do you want to continue and force them to shut down(type 'Y', then enter) or quit(Just hit enter)?"
    if($continueWithShutdown -ne 'Y'){
      Write-Host "Good day then!"
      exit  
    }
}
Write-host "Preparing to Power off the following machines that did not shutdown properly:"
Write-Host "------------------SHUTDOWN ALL MACHINES THAT ARE STILL ON!------------------" -foregroundcolor yellow
forEach ($VM in $StillOnVMs){
  PowerOff-Machine -MachineName $VM.Name -wait 1 -force $true
}
Write-Host "---------------------------SHUTDOWN ALL PRIMARIES!--------------------------" -foregroundcolor yellow
#Power Down Primaries>Graceful
#Ordered shutdown of remaining VMs
#Windows Machines
Check-VMTools -MachineName "<Primary Server 1>"
PowerOff-Machine -MachineName "<Primary Server 1>" -wait 10
Write-Host "-------------------------------------------"
Check-VMTools -MachineName "<Primary Server 2>"
PowerOff-Machine -MachineName "<Primary Server 2>" -wait 10
Write-Host "-------------------------------------------"
Check-VMTools -MachineName "<Primary Server 3>"
PowerOff-Machine -MachineName "<Primary Server 3>" -wait 10
Write-Host "-------------------------------------------"
##########################

foreach($hostIP in $Hosts){
    Disconnect-VIServer -Server $hostIP -confirm:$false
}

# Get Finish time, compute and display total time script ran
$ScriptFinishTime = (Get-Date)
Write-Host "The current time is $ScriptFinishTime"
$TimeForScript = (New-TimeSpan -Start $ScriptStartTime -End $ScriptFinishTime)
Write-Host "The script ran for a total time in HH:MM:SS of $TimeForScript"

[System.Windows.Forms.MessageBox]::Show('VMs Powered Off!','All Done','OK','Info');