###########################################################
#-- Script: DeleteSnapshotChoose.ps1
#-- Created: 10/30/2019
#-- Author: Ben Lucas 
#-- Description: Connects to ESXi 6 or above host and allows for group deletion 
#-- of snapshots and single deletion if snapshots number or order is different from 
#-- a set server/domain controller. 
#-- Must add values to lines 14-18
#--  
#-- History: Created in October 2019 
#-- BL         1.0.0.0 10/30/2019
###########################################################
import-module vmware.vimautomation.core
Add-Type -AssemblyName System.Windows.Forms

$EsxServer = '<Enter ESX Server Name/IP>'
$EsxUser = '<Enter username>'
$ESXPassword = '<Enter Password>'
$DomainControllerName = '<Enter Domain Controller Name>'
$ServersToExclude = "<Name pattern for any VMs you don't want to snap>"

#function region
function connectVIServers{
#Connect-VIServer -Server '<ESX Server Name/IP>' -user '<username>' -Password '<Password>'>>Add more to connect to more ESX servers
Connect-VIServer -Server $EsxServer -user $EsxUser -Password $ESXPassword
}

function disconnectVIServers{
#Connect-VIServer -Server '<ESX Server Name/IP>' -Confirm:$false >>corresponds to multiple additions for connectVIServer
Connect-VIServer -Server $EsxServer -Confirm:$false
}

function listVMSnaps{
    Param(
    [Parameter(Mandatory=$true)]
    [string]$VMToGetSnapListFrom
    )
    $ListNumberCounter = 1
    $Snapshots = get-snapshot -vm $VMToGetSnapListFrom | Select -Unique Name
    write-host ("`nChoose a Snapshot to Delete:"+$VMToGetSnapListFrom+":")
    forEach ($Snap in $Snapshots){
        write-host ("("+ $ListNumberCounter++ +"): " + $Snap.name) -ForegroundColor Green
    
    }     
}
function quitOrContinueOption{
    Write-Host "`nType: " -nonewline
    Write-Host "'q' + [Enter]" -foregroundcolor red -nonewline
    Write-Host " to QUIT" 
    Write-Host "Type: " -nonewline
    Write-Host "[Enter]" -foregroundcolor green -nonewline
    $response = Read-Host " to CONTINUE" 
    if($response.ToString().ToLower() -eq 'q'){
        disconnectVIServers
        exit
    }
}

function quitSkipOrContinueOption{
    Write-Host "`nType: " -nonewline
    Write-Host "'q' + [Enter]" -foregroundcolor red -nonewline
    Write-Host " to QUIT" 
    Write-Host "Type: " -nonewline
    Write-Host "'s'" -foregroundcolor green -nonewline
    Write-Host " to skip VM"  
    Write-Host "Type: " -nonewline
    Write-Host "[Enter]" -foregroundcolor green -nonewline
    $response = Read-Host " to CONTINUE" 
    if($response.ToString().ToLower() -eq 'q'){
        disconnectVIServers
        exit
    }
    if($response.ToString().ToLower() -eq 's'){
        $skipSnap = $true
    }
}
#Variable Region
$ListNumberCounter = 1 #written to host number signifying the number of the snapshot for that VM
$VMsWithDifferingSnaps = @() #list of snaps with differing number from the average or snapshot names mismatched from DC01
[bool]$SnapsAreDifferent = $false  
$SnapToDeleteIndex = -1
$skipSnap = $false

#Execution Region
connectVIServers
$VMs = Get-VM | Where-Object {$_.name -notlike ('*'+$ServersToExclude+'*')}   | Sort-Object | Get-Unique #All VMs
$DomainController = get-vm | Where-Object {$_.Name -like ('*'+$DomainControllerName+'*')}  | Get-Unique
$DomainControllerSnaps = get-snapshot -vm $DomainController  | Select -Unique Name #snapshots should match Domain Controller's snapshots
#check snapshot differences
forEach ($VM in $VMs){
    $snapCounter = 0
    $Snapshots = get-snapshot -vm $VM | Select -Unique Name
    #listVMSnaps $DC01 #This line for debugging
    #listVMSnaps $VM #This line for debugging
    #check number of snapshot differences from the Domain Controller
    if($DomainControllerSnaps.Length -ne $Snapshots.Length){
        $SnapsAreDifferent = $true
        $VMsWithDifferingSnaps += ,$VM
        $VMs = $VMs | Where-Object {$_.Name -ne $VM.Name}
    } else {
        #check snapshot with different names from the Domain Controller       
        forEach ($Snap in $Snapshots){
            if($Snap.Name -ne ($DomainControllerSnaps.Get($snapCounter++)).name){
                $SnapsAreDifferent = $true
                $VMsWithDifferingSnaps += ,$VM
                $VMs = $VMs | Where-Object {$_.Name -ne $VM.Name}
            }
        }        
    }
}

#if there are differeng snapshots then 
if($SnapsAreDifferent){
    #inform user of snapshot differences
    Write-Host "`nThe Snapshots on These VMs differ from the Domain Controller by name, amount or order." -foregroundcolor red
    Write-Host "Best Practices dictate that you should have the same number of snaps with the same names for every VM." -foregroundcolor red
    Write-Host "It may be a good idea to manually remove your snaps if this is not the case." -foregroundcolor red
    Write-Host "If you would like to continue, you will have a chance to decide which snap to delete on differeing VMs later.`n" -foregroundcolor red

    forEach ($VM in $VMsWithDifferingSnaps){
        Write-Host ("$vm.Name") -foregroundcolor magenta
    }
    quitOrContinueOption
}

Write-Host "`n"
#List Snapshots on VMs to delete
listVMSnaps $DomainController

while(($SnapToDeleteIndex -lt 0) -or ($SnapToDeleteIndex -gt $Snapshots.length) -or ($SnapToDeleteIndex -isnot [int])){
    $SnapToDeleteIndex = Read-Host "`nPlease enter the index number of the snapshot you want to delete"
    try{
        $SnapToDeleteIndex = ($SnapToDeleteIndex-1)
        if(($SnapToDeleteIndex -lt 0) -or ($SnapToDeleteIndex -gt $Snapshots.length)-or ($SnapToDeleteIndex -isnot [int])){
            write-host "Please enter a number! Please pick one of the green numbers to the left of the snapshot names.`n" -foreground red
            listVMSnaps $DC01
        }
    }catch{
         write-host "Incorrect snapshot number! Please pick one of the green numbers to the left of the snapshot names.`n" -foreground red
         listVMSnaps $DC01
    }
    

}

forEach ($VM in $VMs)
{
    $Snapshots = get-snapshot -vm $VM | Select -Unique Name
    write-host $VM.name -NoNewline -ForegroundColor green
    write-host "-->> Snapshot that will be deleted: " -NoNewline
    write-host $Snapshots.get($SnapToDeleteIndex).name -ForegroundColor Red
}

$response = Read-Host "Are You Sure You want to delete these Snapshots? Please look at list, they will be gone forever!!` 
-->>Type 'y' to delete these snapshots!!"

if($response -eq 'y'){
    forEach ($VM in $VMs){
        $Snapshots = get-snapshot -vm $VM | Select -Unique Name
        Write-host ("Removing Snapshot: "+$Snapshots.get($SnapToDeleteIndex)+" from VM: "+$VM.Name) -ForegroundColor red
        $SnapToDelete = Get-Snapshot $VM -Name $Snapshots.get($SnapToDeleteIndex).name
        Remove-Snapshot -Snapshot $SnapToDelete -Confirm:$false
    }

}else{
    Write-host "Operation Cancelled, Good day."
    disconnectVIServers
    exit
}

write-host "`nNow would you like to deal with the VMs with differing snapshots?"
quitOrContinueOption

forEach ($VM in $VMsWithDifferingSnaps){
    Write-Host ("`n"+$VM.Name + " Snapshots:")
    listVMSnaps $VM
    quitSkipOrContinueOption
    $SnapToDeleteIndex = -1
    $Snapshots = get-snapshot -vm $VM | Select -Unique Name
    if(!($skipSnap)){
        while(($SnapToDeleteIndex -lt 0) -or ($SnapToDeleteIndex -ge $Snapshots.length) -or ($SnapToDeleteIndex -isnot [int])){
            $SnapToDeleteIndex = Read-Host "`nPlease enter the index number of the snapshot you want to delete"
            try{
                $SnapToDeleteIndex = ($SnapToDeleteIndex-1)
                if(($SnapToDeleteIndex -lt 0) -or ($SnapToDeleteIndex -ge $Snapshots.length)-or ($SnapToDeleteIndex -isnot [int])){
                    write-host "Please enter a number! Please pick one of the green numbers to the left of the snapshot names.`n" -foreground red
                    listVMSnaps $VM.Name
                }
            }catch{
                 write-host "Incorrect snapshot number! Please pick one of the green numbers to the left of the snapshot names.`n" -foreground red
                 listVMSnaps $VM.Name
            }
       }        
    }
    $skipSnap = $false
    write-host $VM.name -NoNewline -ForegroundColor green
    write-host "-->> Snapshot that will be deleted: " -NoNewline
    write-host $Snapshots.get($SnapToDeleteIndex).name -ForegroundColor Red
    $response = Read-Host "Are You Sure You want to delete these Snapshots? Please look at list, they will be gone forever!!` 
    -->>Type 'y' to delete these snapshots!!"

    if($response -eq 'y'){
        $Snapshots = get-snapshot -vm $VM | Select -Unique Name
        Write-host ("Removing Snapshot: "+$Snapshots.get($SnapToDeleteIndex)+" from VM: "+$VM.Name) -ForegroundColor red
        $SnapToDelete = Get-Snapshot $VM -Name $Snapshots.get($SnapToDeleteIndex).name
        Remove-Snapshot -Snapshot $SnapToDelete -Confirm:$false

    }else{
        Write-host "Operation Cancelled, moving to next VM"
    }

}

disconnectVIServers

Write-Host "Done-zo!"
[System.Windows.Forms.MessageBox]::Show('Snapshot Deletion Complete!','All Done','OK','Info');
