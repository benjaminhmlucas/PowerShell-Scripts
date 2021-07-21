###########################################################
#-- Script: CheckVMsForUSBVirtualHardware.ps1
#-- Created: 9/3/2020
#-- Author: Ben Lucas
#-- Description: Checks All VMs for USB drives, reports the 
#-- name of VMs with USB.
#-- History: Created by Ben Lucas
#-- BL        1.0.0.0 9/9/2020
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

Foreach ($my_vm in (get-vm)){
    If ($my_vm.ExtensionData.COnfig.Hardware.Device | where {$_ -is [VMware.Vim.VirtualUSBController]}) {
        Write-host ($my_vm.name+": USB is Present!") -ForegroundColor Green
    }Else{
        Write-host ($my_vm.name+": USB Not Present!") -ForegroundColor Red
    }
}

Disconnect-VIServer -Server $ESX01Address -Confirm:$false 
#Disconnect-VIServer -Server $ESX0XAddress -Confirm:$false 

Write-host "----------------------------------------------------"
Write-host "All Done, Please Hit Enter:"
Write-host "----------------------------------------------------"
Read-host