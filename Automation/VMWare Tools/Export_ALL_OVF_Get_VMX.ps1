###########################################################
#-- Script: Export_ALL_OVF_Get_VMX.ps1
#-- Created: 01/10/2019
#-- Author: Ben Lucas
#-- Description: Backup all VM guest to .ova file
#-- History: Combined and refined multiple previous items to cover CANES 2.0.1 and CANES 3.0.0. in June 2019 
#-- SSA         1.0.0.0 01/10/2019
###########################################################

###########################################################
#-- Notes
#-- This is set up for a system that uses RBAC for Domain admins, Server admins and workstations admins
#-- SAUser = <Server Admin User>
#-- DAUser = <Domain Admin User>
#-- WAUser = <Worksation Admin User>
#-- Line 159 sets save location

##########FUNCTIONS################
#If VMTools is not running on the windows machine, you can cause damage by shutting power off abruptly
#this function ensures VMTools is on, on the VM.
function Check-VMTools{
        param (
        [Parameter(Mandatory=$true)]
        $MachineName      
    )
    $Global:VM = Get-VM | Where-object {$_.name -like ("*"+$MachineName)} 
    if($Global:VM.PowerState -like "PoweredOn"){
        $VMName = $MachineName -replace "<Portion of ESX name that you may want to remove if AD name is different>",""
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
######END FUNCTIONS####################
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

#Identify and create location to store backups on machine that this script is running from. It can be a mapped drive
#Modify below based on System being backed up

$BackupDir = "<Save Path for Exports>"
mkdir -Path $BackupDir



#Get list of VM
$VMs = Get-VM
#Disconnect CD
#run through the vm and disconnect the items in the CD Drives for each and set to NoMedia.
forEach ($VM in $VMs)
{
  $status = get-vm $VM | Get-CDDrive | Where-Object { $_.name -like "*1"} |Set-CDDrive -NoMedia -Confirm:$false -ErrorAction SilentlyContinue
  $status = get-vm $VM | Get-CDDrive | Where-Object { $_.name -like "*2"} |Set-CDDrive -NoMedia -Confirm:$false -ErrorAction SilentlyContinue
  $status = get-vm $VM | Get-CDDrive | Where-Object { $_.name -like "*3"} |Set-CDDrive -NoMedia -Confirm:$false -ErrorAction SilentlyContinue
  $status = get-vm $VM | Get-CDDrive | Where-Object { $_.name -like "*4"} |Set-CDDrive -NoMedia -Confirm:$false -ErrorAction SilentlyContinue
  $status = get-vm $VM | Get-CDDrive | Where-Object { $_.name -like "*5"} |Set-CDDrive -NoMedia -Confirm:$false -ErrorAction SilentlyContinue
  $status = get-vm $VM | Get-CDDrive | Where-Object { $_.name -like "*6"} |Set-CDDrive -NoMedia -Confirm:$false -ErrorAction SilentlyContinue
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
#wait a little longer for good measure
Start-sleep -Seconds 60

#Consolidate Snapshots
forEach ($VM in $VMs)
{
  $Snapshots = get-snapshot -vm $VM
  write-host "Here is the Initial list of snapshots: $Snapshots"
    forEach ($snapshot in $Snapshots)
    {
        try{
            Remove-Snapshot -snapshot $snapshot -RemoveChildren -confirm:$false
            start-sleep -Seconds 10         
        }catch{
            #Do Nothing benign errors expected
        }
    }
    
}

##Export and get .vmx files for each VM 
#This is necessary if the VMs use VMXNET3 for there virtual NIC cards.  When importing you have to replace the created 
#VMX file in the Datastore with the old one that is copied here
$VMs = Get-VM 
    forEach ($VM in $VMs)
         {              
             #Provide the name for Each VM as it is being backed up as well as the start time
             $BackupStartDate = (Get-Date)
             Write-Host ""
             Write-Host ""
             Write-Host "Starting backup of $VM at $BackupStartDate"
                                
             #Dynamically create a folder and Export the VM. Note... The OVF format Provides multiple files for each vm
             ####$VMName = $VM.Name
             Export-VApp -Destination $BackupDir\ -VM $VM -Format OVF 
             Start-sleep -seconds 2

        
             #Get copy of .vmx file to be used during import of machine on different Host
             $datastore = Get-VM $VM | Get-Datastore
             New-PSDrive -Location $datastore -Name ds -PSProvider VimDatastore -Root "\" 
             Start-sleep -seconds 2
             Set-Location ds:\
             $VMXStorage = "$BackupDir\$VM\"
             Write-host "copying .vmx file for $VM"
             Get-ChildItem -filter ("$VM.vmx") -recurse  | Copy-DatastoreItem -destination $VMXStorage
             $Check = Test-path "$BackupDir\$VM\$VM.vmx"
             if($Check -eq $True) {Write-Host -ForegroundColor Green "VMX for $VM Copied"}
             if($Check -eq $False) {Write-Host -ForegroundColor Red "VMX for $VM FAILED TO COPY"}
             Remove-PSDrive -Name ds -Force
             set-location C:\
         }



# Get Finish time, compute and display total time script ran
$ScriptFinishTime = (Get-Date)
Write-Host "The current time is $ScriptFinishTime"
$TimeForScript = (New-TimeSpan -Start $ScriptStartTime -End $ScriptFinishTime)
Write-Host "The total time to prepare and perform backup in HH:MM:SS was $TimeForScript"

Write-Host "Backup complete..."
Write-Host "CONTINUING"


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



##Ridiculous amounts of checks before closing script
Read-host -Prompt "Please examine and then capture the content of this window and store with the backups for future reference and then press ENTER to continue."
Read-host -Prompt "Double checking. Do you want me to close this window now?  press ENTER to close"

