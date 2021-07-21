###########################################################
#-- Script: ForceGPUpdateOnAllWindowsVMs.ps1
#-- Created: 1/24/2020
#-- Author: Atlas Technologies Technologies
#-- Description: Forces GP Updates on all windows machines 
#-- in the domain in certain OUs
#-- History: Created in January 2020 by Ben Lucas
#-- SSA         1.0.0.0 1/24/2020
###########################################################

###########################################################
#-- Notes
#-- This is set up for a system that uses RBAC for Domain admins, Server admins and workstations admins
#-- SAUser = <Server Admin User>
#-- DAUser = <Domain Admin User>
#-- WAUser = <Worksation Admin User>

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
$global:credentialList = @($global:WAUser,$global:DAUser,$global:SAUser)

$global:DC = "<Domain Controller Name>"
$global:domainControllerOU = "*Domain Controllers*"
$global:ServerOU = "*Servers*"
$global:workstationOU = "*Workstations*"

#Get Start time
$ScriptStartTime = (Get-Date)
Write-Host The current time is $ScriptStartTime

$global:ComputerScriptIsRunningFrom = $env:COMPUTERNAME

#Get AD Module
if(Test-WSMan $global:DC -ErrorAction SilentlyContinue){
    try{
        $sess = New-PSSession -ComputerName $global:DC -Credential $global:DAUser    
        Write-host "Connected, Getting AD Module"
        Import-Module ActiveDirectory -PSSession $sess
    }Catch{
        Read-host "Incorrect Password! Run script again! Hit Enter To Exit:"
        Exit
    }

}

#Determines which machines to ping from based on OU
$DomainControllersToTestList = Get-ADComputer -Filter * -Credential $global:DAUser | Where-Object {$_.DistinguishedName -like $global:domainControllerOU}  | Sort-Object -Property name #this variable holds all Domain Controllers are used for the test
$MemberServersToTestList = Get-ADComputer -Filter * -Credential $global:DAUser | Where-Object {$_.DistinguishedName -like $global:ServerOU}  | Sort-Object -Property name #this variable holds all Windows Member Servers are used for the test
$WorkstationsToTestList = Get-ADComputer -Filter * -Credential $global:DAUser | Where-Object {$_.DistinguishedName -like $global:workstationOU} #workstations with PSRemoting enabled

$FullComputerTestList = @()
foreach($comp in $DomainControllersToTestList){$FullComputerTestList+=$comp}
foreach($comp in $MemberServersToTestList){$FullComputerTestList+=$comp}
foreach($comp in $WorkstationsToTestList){$FullComputerTestList+=$comp}

#remove copmuter that is running the script
$FullComputerTestList = $FullComputerTestList | Where-Object {$_.distinguishedName -notlike ("*"+$global:ComputerScriptIsRunningFrom+"*")}

#run script on current computer
Write-Host ("----------------------------------------------------------")
Write-Host ("Running test on this computer:")
write-host ($env:USERNAME+" is currently connected to: " + $env:COMPUTERNAME);
Write-Host ("----------------------------------------------------------")

#This code should be identical to what entered below
#This is code that is run on the computer that the script is being run on.
###########Start Code Here############
$result = Gpupdate /force
write-host ("Force Update feedback:"+$result)
############End Code Here#############

foreach($comp in $FullComputerTestList){
    
    If({$comp.DistinguishedName -like $global:domainControllerOU}){$currentUser = $global:DAUser}
    If($comp.DistinguishedName -like $global:ServerOU){$currentUser = $global:SAUser}
    If($comp.DistinguishedName -like $global:workstationOU){$currentUser = $global:wauser}
    
    if(Test-WSMan $comp.Name -ErrorAction SilentlyContinue){
        
        $output = Invoke-Command -Computername $comp.name -ScriptBlock{
            $VerbosePreference='Continue';
                
            Write-Host ("----------------------------------------------------------")
            write-host ($env:USERNAME+" is currently connected to: " + $env:COMPUTERNAME) -ForegroundColor Magenta
            Write-Host ("----------------------------------------------------------")
            try{
                #This code should be identical to what entered above
                #######CODE TO RUN ON REMOTE COMPUTER#######
                $result = Gpupdate /force
                write-host ("Force Update feedback:"+$result)
                Start-Sleep -Seconds 90 #give time to finish, adjust as needed
                ##############END OF REMOTE CODE############
            }Catch{
                write-host "An Error Occured:" -ForegroundColor Red;
                write-host $Error[0] -ForegroundColor Red;
            }       
        
        } -Credential $currentUser 

    }else{
        write-host ("---------------------------------------------------------")
        write-host ("Test-WSMan FAILED on: "+$comp.name) -ForegroundColor Red
    }
}
# Get Time and display
$ScriptFinishTime = (Get-Date)
write-host ("---------------------------------------------------------")
Write-Host "The current time is $ScriptFinishTime"

# Compute the time required for the whole script to run
$TimeForScript = (New-TimeSpan -Start $ScriptStartTime -End $ScriptFinishTime)
Write-Host "The script ran for a total time in HH:MM:SS of $TimeForScript"

Read-host "DONE! Hit Enter To Exit:"