﻿###########################################################
#-- Script: Check-RBAC-OnAllWindowsVMs.ps1
#-- Created: 1/24/2020
#-- Author: Atlas Technologies Technologies
#-- Description: A Template to run PowerShell commands on all Windows Servers and Workstations
#-- History: Created in January 2020 by Ben Lucas
#-- SSA         1.0.0.0 1/24/2020
###########################################################

#Get Admin Credentials
$global:DAUser = Get-Credential -Credential "domain\domainAdminUser"
$global:user = New-Object System.Management.Automation.PSCredential ("domain\regularUser",$global:DAUser.Password)
$global:SAUser = New-Object System.Management.Automation.PSCredential ("domain\serverAdminUser",$global:DAUser.Password)
$global:WAUser = New-Object System.Management.Automation.PSCredential ("domain\workstationAdminUser",$global:DAUser.Password)

$global:credentialList = @($global:user,$global:WAUser,$global:DAUser,$global:SAUser)

$global:DC = "DC01"
$global:domainControllerOU = "*Domain Controllers*"
$global:memberServerOU = "*Member Servers*"
$global:workstationOU = "*COMPUTERS*"

#Get Start time
$ScriptStartTime = (Get-Date)
Write-Host The current time is $ScriptStartTime

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

$DomainControllersToTestList = Get-ADComputer -Filter * -Credential $global:DAUser | Where-Object {$_.DistinguishedName -like $global:domainControllerOU -or $_.DistinguishedName -like "*MCA*"} | Sort-Object -Property name #this variable holds all Domain Controllers are used for the test
$MemberServersToTestList = Get-ADComputer -Filter * -Credential $global:DAUser | Where-Object {($_.DistinguishedName -like $global:memberServerOU -and $_.name -ne "VCSA") -and ($_.DistinguishedName -like $global:memberServerOU -and $_.name -ne "MCA01")} | Sort-Object -Property name #this variable holds all Windows Member Servers are used for the test
$WorkstationsToTestList = Get-ADComputer -Filter * -Credential $global:DAUser | Where-Object {$_.DistinguishedName -like $global:workstationOU} | Sort-Object -Property name #this variable holds all Windows Workstations that are used for the test
#$WorkstationsToTestList = Get-ADComputer -Filter * -Credential $global:DAUser | Where-Object {$_.DistinguishedName -like $global:workstationOU -and $_.name -like "*U-WS00V1*"} #single workstation with PSRemoting enabled

$FullComputerTestList = @()
foreach($comp in $DomainControllersToTestList){$FullComputerTestList+=$comp}
foreach($comp in $MemberServersToTestList){$FullComputerTestList+=$comp}
foreach($comp in $WorkstationsToTestList){$FullComputerTestList+=$comp}
$FullComputerTestList = $FullComputerTestList

foreach($comp in $FullComputerTestList){
    foreach($credential in $global:credentialList){
        if(Test-WSMan $comp.Name -ErrorAction SilentlyContinue){
            $output = Invoke-Command -Computername $comp.name -ScriptBlock{
                $VerbosePreference='Continue';
                
                Write-Host ("----------------------------------------------------------")
                write-host ($env:USERNAME +" is currently connected to: " + $env:COMPUTERNAME);
                Write-Host ("----------------------------------------------------------")
       
            } -Credential $credential -ErrorAction SilentlyContinue

        }else{write-host ("Test-WSMan FAILED on: "+$comp.name+" Make Sure PSRemoting is enabled for this device.");break;}            
    }
}
# Get Time and display
$ScriptFinishTime = (Get-Date)
Write-Host "The current time is $ScriptFinishTime"

# Compute the time required for the whole script to run
$TimeForScript = (New-TimeSpan -Start $ScriptStartTime -End $ScriptFinishTime)
Write-Host "The script ran for a total time in HH:MM:SS of $TimeForScript"

Read-host "DONE! Hit Enter To Exit:"