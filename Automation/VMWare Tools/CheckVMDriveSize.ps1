###########################################################
#-- Script: CheckVMDriveSize.ps1
#-- Created: 9/3/2020
#-- Author: Ben Lucas
#-- Description: Checks provisioned drive sizes for all VMs 
#-- on the ESX host.
#-- History: Created by Ben Lucas
#-- BL        1.0.0.0 9/9/2020
###########################################################
$ESX01Address = '<IP for ESX Host>'
$cred = get-credential "<username for ESX Host>"

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
  
try{
    Connect-VIServer -Server $ESX01Address -user $cred.UserName -Password $cred.GetNetworkCredential().Password -ErrorAction SilentlyContinue
    #Connect-VIServer -Server $ESX0XAddress -user $cred.UserName -Password $cred.GetNetworkCredential().Password -ErrorAction SilentlyContinue
    if($? -eq $false){throw $error[0].exception}   
}catch [Exception]{
    Read-Host "Wrong Credentials for ESX host. Hit enter to exit..." -
    exit
}

$SizeList = Get-VM|Select-Object Name,ProvisionedSpaceGB,@{n="HardDiskSizeGB";e={(Get-HardDisk -VM $_ | Measure-Object -Sum CapacityGB).Sum}}
$UsedTotal = 0
$provsionedTotal = 0
foreach($x in $SizeList){
$UsedTotal += [Math]::Round($x.HardDiskSizeGB,2)
$provsionedTotal += [Math]::Round($x.ProvisionedSpaceGB,2)
write-host "-------------------------------------------------------------"
write-host $x.Name
write-host ("Used:"+[Math]::Round($x.HardDiskSizeGB,2))
write-host ("Prov:"+[Math]::Round($x.ProvisionedSpaceGB,2))
} 

write-host "-------------------------------------------------------------"
write-host "-------------------------------------------------------------"
write-host "Total Used: $UsedTotal"
write-Host "Total Provisioned: $provsionedTotal"
write-host "-------------------------------------------------------------"
write-host "-------------------------------------------------------------"
