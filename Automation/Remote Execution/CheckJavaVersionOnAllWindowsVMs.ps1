###########################################################
#-- Script: CheckJavaVersionOnAllWindowsVMs.ps1
#-- Created: 2/4/2020
#-- Author: Atlas Technologies Technologies
#-- 
#-- Description: Checks in Java folder locations on each VM, returns version number if present.  
#-- The first computer is always the one that the script is being run from, then all other computers 
#-- are tested alphabetically.
#--
#-- History: Created in January 2020 by Ben Lucas
#-- SSA         1.0.0.0 2/4/2020
###########################################################

#Get Admin Credentials
$global:DAUser = Get-Credential -Credential "<domain>\domain.admin"
$global:user = New-Object System.Management.Automation.PSCredential ("<domain>\reg.user",$global:DAUser.Password)
$global:WAUser = New-Object System.Management.Automation.PSCredential ("<domain>\workstation.admin",$global:DAUser.Password)
$global:EAUser = New-Object System.Management.Automation.PSCredential ("<domain>\enterprise.admin",$global:DAUser.Password)
$global:SAUser = New-Object System.Management.Automation.PSCredential ("<domain>\server.admin",$global:DAUser.Password)
$global:NAUser = New-Object System.Management.Automation.PSCredential ("<domain>\network.admin",$global:DAUser.Password)
$global:credentialList = @($global:user,$global:WAUser,$global:DAUser,$global:EAUser,$global:SAUser,$global:NAUser)

$global:DC = "<Main Domain Controller>"
$global:domainControllerOU = "*Domain Controllers*"
$global:memberServerOU = "*Member Servers*"
$global:workstationOU = "*Workstations*"

$global:ComputerScriptIsRunningFrom = $env:COMPUTERNAME

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

$DomainControllersToTestList = Get-ADComputer -Filter * -Credential $global:DAUser | Where-Object {$_.DistinguishedName -like $global:domainControllerOU}  | Sort-Object -Property name #this variable holds all Domain Controllers are used for the test
$MemberServersToTestList = Get-ADComputer -Filter * -Credential $global:DAUser | Where-Object {($_.DistinguishedName -like $global:memberServerOU) -and ($_.DistinguishedName -like $global:memberServerOU -and $_.name -ne "MCA01")}  | Sort-Object -Property name #this variable holds all Windows Member Servers are used for the test
$WorkstationsToTestList = Get-ADComputer -Filter * -Credential $global:DAUser | Where-Object {$_.DistinguishedName -like $global:workstationOU} #single workstation with PSRemoting enabled

$FullComputerTestList = @()
foreach($comp in $DomainControllersToTestList){$FullComputerTestList+=$comp}
foreach($comp in $MemberServersToTestList){$FullComputerTestList+=$comp}
foreach($comp in $WorkstationsToTestList){$FullComputerTestList+=$comp}

$FullComputerTestList = $FullComputerTestList | Where-Object {$_.distinguishedName -notlike ("*"+$global:ComputerScriptIsRunningFrom+"*")}

Write-Host ("----------------------------------------------------------")
write-host ($env:USERNAME+" is currently connected to: " + $env:COMPUTERNAME);
Write-Host ("----------------------------------------------------------")

$javaInfo = ''
$javaInfo = gci ("C:\Program Files (x86)\Java\jre8\bin\java.exe") -ErrorAction SilentlyContinue
if($javaInfo.VersionInfo.FileVersion){                
    write-host ("Java version: "+$javaInfo.VersionInfo.FileVersion+" For x32") -ForegroundColor Green          
}else{
    write-host ("Java not present on: "+ $env:computername +" For x32") -ForegroundColor Red
}

$javaInfo = ''
$javaInfo = gci ("C:\Program Files\Java\jre8\bin\java.exe") -ErrorAction SilentlyContinue
if($javaInfo.VersionInfo.FileVersion){                
    write-host ("Java version: "+$javaInfo.VersionInfo.FileVersion+" For x64") -ForegroundColor Green          
}else{
    write-host ("Java not present on: "+ $env:computername+" For x64") -ForegroundColor Red
}

foreach($comp in $FullComputerTestList){
    
    If({$comp.DistinguishedName -like $global:domainControllerOU}){$currentUser = $global:DAUser}
    If($comp.DistinguishedName -like $global:memberServerOU){$currentUser = $global:SAUser}
    If($comp.DistinguishedName -like $global:workstationOU){$currentUser = $global:wauser}
    
    if(Test-WSMan $comp.Name -ErrorAction SilentlyContinue){
        
        $output = Invoke-Command -Computername $comp.name -ScriptBlock{
            $VerbosePreference='Continue';
                
            Write-Host ("----------------------------------------------------------")
            write-host ($env:USERNAME+" is currently connected to: " + $env:COMPUTERNAME);
            Write-Host ("----------------------------------------------------------")
            try{
                $javaInfo = ''
                $javaInfo = gci ("C:\Program Files (x86)\Java\jre8\bin\java.exe") -ErrorAction SilentlyContinue
                if($javaInfo.VersionInfo.FileVersion){                
                    write-host ("Java version: "+$javaInfo.VersionInfo.FileVersion+" For x32") -ForegroundColor Green          
                }else{
                    write-host ("Java not present on: "+ $env:computername +" For x32") -ForegroundColor Red
                }
                $javaInfo = ''
                $javaInfo = gci ("C:\Program Files\Java\jre8\bin\java.exe") -ErrorAction SilentlyContinue
                if($javaInfo.VersionInfo.FileVersion){                
                    write-host ("Java version: "+$javaInfo.VersionInfo.FileVersion+" For x64") -ForegroundColor Green          
                }else{
                    write-host ("Java not present on: "+ $env:computername+" For x64") -ForegroundColor Red
                }

            }Catch{
                write-host "An Error Occured:" -ForegroundColor Red;
                write-host $Error[0] -ForegroundColor Red;
            }       
        
        } -Credential $currentUser 

    }else{write-host ("Test-WSMan FAILED on: "+$comp.name)}
}
# Get Time and display
$ScriptFinishTime = (Get-Date)
Write-Host "The current time is $ScriptFinishTime"

# Compute the time required for the whole script to run
$TimeForScript = (New-TimeSpan -Start $ScriptStartTime -End $ScriptFinishTime)
Write-Host "The script ran for a total time in HH:MM:SS of $TimeForScript"

Read-host "DONE! Hit Enter To Exit:"