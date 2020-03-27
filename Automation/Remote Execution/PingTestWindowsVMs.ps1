###########################################################
#-- Script: PingTestWindowsVMs.ps1
#-- Created: 3/27/2020
#-- Author: Ben Lucas
#-- Description: Script that allows the user to ping every address listed on line 12.  
#-- Controls for which VMs to Ping from are on lines 72-76.  Script will decide which user
#-- to log in as based on OU(except MCA01). Tested when ran from inside domain. 
#-- Compatible with PowerShell 3 or greater
#--
#-- History: Created in January 2020 by Ben Lucas
#-- 1.0.0.0 3/27/2020
###########################################################

####################Functions##########################
Function pingTest{
    $global:ipsToPing = ('192.168.1.1','192.168.1.2','192.168.1.3','164.191.232.1')#<-All values must be <xxx.xxx.xxx.xxx> Format!!#
    write-Host "Running Control Tests->" -ForegroundColor Yellow
    write-Host "Known Good:" -ForegroundColor Yellow
    If(Test-Connection -ComputerName 127.0.0.1 -ErrorAction Ignore -Count 1){
        Write-host "Successful Ping on 127.0.0.1!" -ForegroundColor Green
    }else{
        Write-host "Failed to Ping 127.0.0.1!" -ForegroundColor Red
    }    write-Host "Known Bad:" -ForegroundColor Yellow
    If(Test-Connection -ComputerName 0.0.0.0 -ErrorAction Ignore -Count 1){
        Write-host "Successful Ping on 0.0.0.0!" -ForegroundColor Green
    }else{
        Write-host "Failed to Ping 0.0.0.0!" -ForegroundColor Red
    }  #Test Control ->This will always fail
    write-Host "Running Tests..." -ForegroundColor Yellow
        foreach($ip in $global:ipsToPing){
        If(Test-Connection -ComputerName $ip -ErrorAction Ignore -Count 1){
            Write-host "Successful Ping on $ip!" -ForegroundColor Green
        }else{
            Write-host "Failed to Ping $ip!" -ForegroundColor Red
        }
    }
}
##################End Functions#######################

#Get Admin Credentials
$global:DAUser = Get-Credential -Credential "<FQDN>\domainAdmin"
$global:user = New-Object System.Management.Automation.PSCredential ("<FQDN>\regUser",$global:DAUser.Password)
$global:WAUser = New-Object System.Management.Automation.PSCredential ("<FQDN>\workstationAdmin",$global:DAUser.Password)
$global:SAUser = New-Object System.Management.Automation.PSCredential ("<FQDN>\serverAdmin",$global:DAUser.Password)
$global:credentialList = @($global:user,$global:WAUser,$global:DAUser,$global:SAUser)

$global:DC = "DC01"
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
$DomainControllersToTestList = Get-ADComputer -Filter * -Credential $global:DAUser | Where-Object {$_.DistinguishedName -like $global:domainControllerOU -or $_.DistinguishedName -like "*MCA*"}  | Sort-Object -Property name #this variable holds all Domain Controllers are used for the test
$MemberServersToTestList = Get-ADComputer -Filter * -Credential $global:DAUser | Where-Object {($_.DistinguishedName -like $global:memberServerOU -and $_.name -ne "VCSA") -and ($_.DistinguishedName -like $global:memberServerOU -and $_.name -ne "MCA01")}  | Sort-Object -Property name #this variable holds all Windows Member Servers are used for the test
$WorkstationsToTestList = Get-ADComputer -Filter * -Credential $global:DAUser | Where-Object {$_.DistinguishedName -like $global:workstationOU -and $_.name -like "*U-WS00V1*"} #single workstation with PSRemoting enabled
#$WorkstationsToTestList = Get-ADComputer -Filter * -Credential $global:DAUser | Where-Object {$_.DistinguishedName -like $global:workstationOU} #this variable holds all Windows Workstations that are used for the test

$FullComputerTestList = @()

foreach($comp in $DomainControllersToTestList){$FullComputerTestList+=$comp}
foreach($comp in $MemberServersToTestList){$FullComputerTestList+=$comp}
foreach($comp in $WorkstationsToTestList){$FullComputerTestList+=$comp}

#remove copmuter that is running the script from the $FullComputerTestList list so to avoid errors and double testing
$FullComputerTestList = $FullComputerTestList | Where-Object {$_.distinguishedName -notlike ("*"+$global:ComputerScriptIsRunningFrom+"*")}

#run script on current computer
Write-Host ("----------------------------------------------------------")
Write-Host ("Running test on this computer:")
write-host ($env:USERNAME+" is currently connected to: " + $env:COMPUTERNAME);
Write-Host ("----------------------------------------------------------")

#This is code that is run on the computer that the script is being run on.

######################################
###########Start Code Here############

pingTest

############End Code Here#############
######################################
foreach($comp in $FullComputerTestList){
    
    #Select User Based on computer OU#
    If({$comp.DistinguishedName -like $global:domainControllerOU -or $comp.DistinguishedName -like "*MCA*"}){$currentUser = $global:DAUser}
    If($comp.DistinguishedName -like $global:memberServerOU -and $comp.DistinguishedName -notlike "*MCA*"){$currentUser = $global:SAUser}
    If($comp.DistinguishedName -like $global:workstationOU){$currentUser = $global:wauser}
    
    #Captures Ping Function and passes it to the remote computer
    $PingTest = Get-Item Function:\pingTest
    
    if(Test-WSMan $comp.Name -ErrorAction SilentlyContinue){
        $output = Invoke-Command -Computername $comp.name -ScriptBlock{
            Param($PingTest)
            
            Write-Host ("----------------------------------------------------------")
            write-host ($env:USERNAME+" is currently connected to: " + $env:COMPUTERNAME);
            Write-Host ("----------------------------------------------------------")
            
            try{
                ############################################
                #######CODE TO RUN ON REMOTE COMPUTER#######
                
                Invoke-Expression $pingTest.ScriptBlock
                
                ##############END OF REMOTE CODE############
                ############################################

            }Catch{
                write-host "An Error Occured:" -ForegroundColor Red;
                write-host $Error[0] -ForegroundColor Red;
                write-host $Error[0].FullyQualifiedErrorId -ForegroundColor Red;
                write-host $Error[0].ScriptStackTrace -ForegroundColor Red;
                write-host $Error[0].InvocationInfo.PositionMessage -ForegroundColor Red;
                write-host $Error[0].InvocationInfo.MyCommand -ForegroundColor Red;
            }       
        
        } -ArgumentList ($PingTest) -Credential $currentUser
    }else{write-host ("Test-WSMan FAILED on: "+$comp.name)}
} 
# Get Time and display
$ScriptFinishTime = (Get-Date)
Write-Host "The current time is $ScriptFinishTime"

# Compute the time required for the whole script to run
$TimeForScript = (New-TimeSpan -Start $ScriptStartTime -End $ScriptFinishTime)
Write-Host "The script ran for a total time in HH:MM:SS of $TimeForScript"

Read-host "DONE! Hit Enter To Exit:"