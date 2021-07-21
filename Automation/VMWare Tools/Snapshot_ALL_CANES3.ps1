###########################################################
#-- Script: Snapshot_ALL_CANES3.ps1
#-- Created: 10/1/2018
#-- Author: Ben Lucas Supporting SSA CM and SQT Decks
#-- Description: Reads name of snaphsot input, removes all CDs from drives, 
#-- snapshots all machines using name from user
#-- History: Created by Ben Lucas
#-- BL        1.0 5/12/2020
#-- BL        1.1 7/21/2021
###########################################################

#Preliminary steps
#Load the VMWare PowerCLI SnapIn so that PowerCLI commandlets can be used

import-module vmware.vimautomation.core
Add-Type -AssemblyName System.Windows.Forms

#Set Snapshot Name
$nameCheck = 0
while($nameCheck -ne 1){
    [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.VisualBasic') |
    Out-Null
    $SnapshotName = [Microsoft.VisualBasic.Interaction]::InputBox("Enter a Snapshot Name. To exit leave name empty & hit OK, or click Cancel","Snapshot","$snapName");
    if($SnapshotName -eq ''){
        exit
    } else{
        Write-Host "Snapshot will be named: $SnapshotName";
        $nameCheckResponse = [System.Windows.Forms.MessageBox]::Show('Are you sure this is the right name? ' + $SnapshotName,'Name Check','OKCancel','Info');
        switch ($nameCheckResponse){
            'OK'{$nameCheck = 1};
        }
    }

}
Start-sleep -Seconds 5

#Get Start time
$ScriptStartTime = (Get-Date)
Write-Host The current time is $ScriptStartTime
$BackupDate = (Get-Date -format ddMMMyyyy)

##Build a list of Hosts.  
$Hosts = @("<list of ESX host names>")

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

$VMs = Get-VM | Sort-Object | Get-Unique
#Disconnect CD
#run through the vm and disconnect the items in the CD Drives for each and set to NoMedia.
Write-Host Disconnecting CD drives
forEach ($VM in $VMs)
{
  $status = get-vm $VM | Get-CDDrive | Where-Object { $_.name -like "*1"} |Set-CDDrive -NoMedia -Confirm:$false -ErrorAction SilentlyContinue
  $status = get-vm $VM | Get-CDDrive | Where-Object { $_.name -like "*2"} |Set-CDDrive -NoMedia -Confirm:$false -ErrorAction SilentlyContinue
  $status = get-vm $VM | Get-CDDrive | Where-Object { $_.name -like "*3"} |Set-CDDrive -NoMedia -Confirm:$false -ErrorAction SilentlyContinue
  $status = get-vm $VM | Get-CDDrive | Where-Object { $_.name -like "*4"} |Set-CDDrive -NoMedia -Confirm:$false -ErrorAction SilentlyContinue
  $status = get-vm $VM | Get-CDDrive | Where-Object { $_.name -like "*5"} |Set-CDDrive -NoMedia -Confirm:$false -ErrorAction SilentlyContinue
  $status = get-vm $VM | Get-CDDrive | Where-Object { $_.name -like "*6"} |Set-CDDrive -NoMedia -Confirm:$false -ErrorAction SilentlyContinue
}
# Get time, compute and display total time to this point
$CurrentTime = (Get-Date)
Write-Host "The current time is $CurrentTime"
$TimeForScript = (New-TimeSpan -Start $ScriptStartTime -End $CurrentTime)
Write-Host "The script has run for for a total time in HH:MM:SS of $TimeForScript"
Write-Host "All CD that were connected should now be disconnected"
Write-Host "CONTINUING"

#Take Snapshots for each VM using input name from above
$VMs = Get-VM | Sort-Object | Get-Unique
forEach ($VM in $VMs)
{
  New-Snapshot -VM $VM -Name $SnapshotName
}
# Get Finish time, compute and display total time script ran
$ScriptFinishTime = (Get-Date)
Write-Host "The current time is $ScriptFinishTime"
$TimeForScript = (New-TimeSpan -Start $ScriptStartTime -End $ScriptFinishTime)
Write-Host "The total time to prepare and perform snapshot orperation in HH:MM:SS was $TimeForScript"

foreach($hostIP in $Hosts){
    Disconnect-VIServer -Server $hostIP -confirm:$false
}

[System.Windows.Forms.MessageBox]::Show('Snapshot Complete!','All Done','OK','Info');
Start-sleep -seconds 10
