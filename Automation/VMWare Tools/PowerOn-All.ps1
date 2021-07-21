###########################################################
#-- Script: PowerOn-All.ps1
#-- Created: 9/12/2018
#-- Author: Ben Lucas Supporting SSA CM and SQT Decks
#-- Description: Backup all VM guest to .ovf file, based on script by Matt Ratliff
#-- History: Combined and refined multiple previous items in February 2019
#-- 5-12-2020	BL	Removed waiting for a VM that is already powered up
#-- 5-12-2020	BL	Added error handling for Connect-VI
###########################################################
Add-Type -AssemblyName System.Windows.Forms
#Get Start time
$ScriptStartTime = (Get-Date)
$BackupDate = (Get-Date -format ddMMMyyyy)
Write-Host The current time is $ScriptStartTime

#Preliminary steps
#Load the VMWare PowerCLI SnapIn so that PowerCLI commandlets can be used
$SnapIn = "VMware.VimAutomation.Core"
import-module vmware.vimautomation.core

#Connect to an ESX host
#Modify the below to fit your needs. One at a time. may want to manually migrate all machines to ESX01 if multiple hosts
$cred = get-credential "root"  
try{
    Connect-VIServer -Server 164.191.227.28 -user $cred.UserName -Password $cred.GetNetworkCredential().Password -ErrorAction SilentlyContinue
    if($? -eq $false){throw $error[0].exception}   
}catch [Exception]{
    Read-Host "Wrong Credentials for ESX host. Hit enter to exit..." -
    exit
}

function PowerOn-Machine{
    param (
        [Parameter(Mandatory=$true)]
        $MachineName,
        [int]$wait = 5       
    )
    $MachineName = ("*"+$MachineName+"*")
    $VM = ""
    $VM = Get-VM | Where-object {$_.name -like ($MachineName)} 
    if($VM.PowerState -eq "PoweredOff"){
        Start-VM -vm $VM -confirm:$false | Format-Table -Property Name,PowerState
        Write-host ("Waiting for host to boot for " + $wait + " seconds....")
        Start-sleep -Seconds $wait -Verbose   
    }else{
        Write-Host ($VM.name+" is already up!") -ForegroundColor Green
    }
}

#Power On Primaries
Write-host "----------------------------------------------------"
PowerOn-Machine -MachineName "<Primary Server 1>" -wait 90
PowerOn-Machine -MachineName "<Primary Server 2>" -wait 90
PowerOn-Machine -MachineName "<Primary Server 3>" -wait 90

#Power On Everyone that isn't already powered on
$VMs = Get-VM 
$StillOffVMs = $VMs | Where-Object {$_.PowerState -notlike 'PoweredOn'}
foreach($VM in $StillOffVMs){
    PowerOn-Machine -MachineName $VM.Name -wait 5
}
Write-host "----------------------------------------------------"
###########################

foreach($hostIP in $Hosts){
    Disconnect-VIServer -Server $hostIP -confirm:$false
}

# Get Finish time, compute and display total time script ran
$ScriptFinishTime = (Get-Date)
Write-Host "The current time is $ScriptFinishTime"
$TimeForScript = (New-TimeSpan -Start $ScriptStartTime -End $ScriptFinishTime)
Write-Host "The script ran for a total time in HH:MM:SS of $TimeForScript"

[System.Windows.Forms.MessageBox]::Show('VMs Powered On!','All Done','OK','Info');