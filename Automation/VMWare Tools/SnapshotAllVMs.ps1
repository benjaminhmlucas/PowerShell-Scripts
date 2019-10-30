###########################################################
#-- Script: SnapshotAllVMs.ps1
#-- Created: 9/12/2019
#-- Author: Ben Lucas 
#-- Description: Snapshot all VMs for domain, ESX 6 or above
#-- History: Created in August 2019 
#-- BL         1.0.0.0 9/12/2019
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
$BackupDate = (Get-Date -format ddMMMyyyy)
Write-Host The current time is $ScriptStartTime

#Connect to an ESX host
#Connect-VIServer -Server '<ESX Server Name/IP>' -user '<username>' -Password '<Password>'>>Add more to connect to more ESX servers
Connect-VIServer -Server '<ESX Server Name/IP>' -user '<username>' -Password '<Password>'


$VMs = Get-VM
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
$VMs = Get-VM
forEach ($VM in $VMs)
{
  $Snapshots = get-snapshot -vm $VM
  write-host "Here is the list of existing snapshots: $Snapshots"
  Write-host "IGNORE any red that occurrs in this section"
  New-Snapshot -VM $VM -Name $SnapshotName
}
# Get Finish time, compute and display total time script ran
$ScriptFinishTime = (Get-Date)
Write-Host "The current time is $ScriptFinishTime"
$TimeForScript = (New-TimeSpan -Start $ScriptStartTime -End $ScriptFinishTime)
Write-Host "The total time to prepare and perform snapshot orperation in HH:MM:SS was $TimeForScript"

#Connect-VIServer -Server '<ESX Server Name/IP>' -Confirm:$false
Connect-VIServer -Server '<ESX Server Name/IP>' -Confirm:$false

[System.Windows.Forms.MessageBox]::Show('Snapshot Complete!','All Done','OK','Info');
Start-sleep -seconds 10
