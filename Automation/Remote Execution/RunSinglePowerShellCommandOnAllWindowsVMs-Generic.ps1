###########################################################
#-- Script: RunSinglePowerShellCommandOnAllWindowsVMs-CANES1010.ps1
#-- Created: 1/24/2020
#-- Author: Atlas Technologies Technologies
#-- Description: A Template to run PowerShell commands on all Windows Servers and Workstations
#-- History: Created in January 2020 by Ben Lucas
#-- SSA         1.0.0.0 1/24/2020
###########################################################

#Get Admin Credentials
$global:user = Get-Credential -Credential "<domain\credential.user>"

#Get Start time
$ScriptStartTime = (Get-Date)
Write-Host The current time is $ScriptStartTime

#Get AD Module
if(Test-WSMan <Domain Controller> -ErrorAction SilentlyContinue){
    try{
        $sess = New-PSSession -ComputerName <Domain Controller> -Credential $global:user    
        Write-host "Connected, Getting AD Module"
        Import-Module ActiveDirectory -PSSession $sess
    }Catch{
        Read-host "Incorrect Password! Run script again! Hit Enter To Exit:"
        Exit
    }

}

$DomainControllersToTestList = Get-ADComputer -Filter * -Credential $global:user | Where-Object {$_.DistinguishedName -like "*<Domain Controller OU>*"} #this variable holds all Domain Controllers are used for the test
$MemberServersToTestList = Get-ADComputer -Filter * -Credential $global:user | Where-Object {$_.DistinguishedName -like "*<Member Server OU>*"} #this variable holds all Windows Member Servers are used for the test
$WorkstationsToTestList = Get-ADComputer -Filter * -Credential $global:user | Where-Object {$_.DistinguishedName -like "*<Workstation OU>*"} #this variable holds all Windows Member Servers are used for the test

$FullComputerTestList = @()
foreach($comp in $DomainControllersToTestList){$FullComputerTestList+=$comp}
foreach($comp in $MemberServersToTestList){$FullComputerTestList+=$comp}
foreach($comp in $WorkstationsToTestList){$FullComputerTestList+=$comp}

foreach($comp in $FullComputerTestList){
    if(Test-WSMan $comp.Name -ErrorAction SilentlyContinue){
        
        $output = Invoke-Command -Computername $comp.name -ScriptBlock{
            $VerbosePreference='Continue';
                
            Write-Host ("----------------------------------------------------------")
            write-host ("I am currently connected to: " + $env:COMPUTERNAME);
            Write-Host ("----------------------------------------------------------")
            try{
            #######CODE TO RUN ON REMOTE COMPUTER#######


            ##############END OF REMOTE CODE############
            }Catch{
                write-host "An Error Occured:" -ForegroundColor Red;
                write-host $Error[0] -ForegroundColor Red;
            }       
        
        } -Credential $global:user        

    }
}
# Get Time and display
$ScriptFinishTime = (Get-Date)
Write-Host "The current time is $ScriptFinishTime"

# Compute the time required for the whole script to run
$TimeForScript = (New-TimeSpan -Start $ScriptStartTime -End $ScriptFinishTime)
Write-Host "The script ran for a total time in HH:MM:SS of $TimeForScript"

Read-host "DONE! Hit Enter To Exit:"