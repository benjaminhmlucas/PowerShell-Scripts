###########################################################
#-- Script: Test-ExternalSiteTest-Single.ps1
#-- Created: 8/7/2018
#-- Author: Ben Lucas 
#-- Description: Creates a session to the passed in computer and attempts to connect to sites in the site list.  
#-- The script uses a log file to record results.  Log file is overwritten each time script is ran. 
#--  
#-- History: Created in October 2019 
#-- BL         1.0.0.0 10/10/2019
#-- BL         1.0.0.1 10/22/2019 ->Troubleshooting
#-- BL         1.0.0.2 10/28/2019 ->Fixed Error Reporting issue
###########################################################
param (
    [Parameter(Mandatory=$true)]
    [string]$ComputerToConnectFrom,
    [bool]$runFromOtherScript = $false
)

Add-Type -AssemblyName System.Windows.Forms
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

#sites to test connectivity and rendering on
string[]]$SiteList = @(
    "http://www.google.com",
    "https://www.facebook.com/",
    "https://www.othersite1.com"
)

#Set Log Variables----------------------------------Set variables between <>'s one lines 29,31,32 and 35---->
$logFile = "C:\<Your log folder>\ExternalSiteTestLog.txt" #file Path must exists
#set credential variables
$regUserName = "<regular user>"
$regUserPwd = ConvertTo-SecureString -String "<Password>" -AsPlainText -Force
$regUser = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $regUserName,$regUserPwd
#set proxy variables
$proxyString = "<Your Proxy Server>.<FQDN>:8080" # Example:"http://proxyServer01.<FQDN>:8080"
$proxyURI = new-object System.uri($proxyString)
[System.Net.WebRequest]::DefaultWebProxy = new-object System.net.webproxy ($proxyURI, $true)
[System.Net.WebRequest]::DefaultWebProxy.credentials = $regUser

#Functions------------------------------------------------------------------
function Test-SiteList{
    param (
        [Parameter(Mandatory=$true)]
        [string]$browserType
    )
    forEach($site in $SiteList){
        write-host "`n`n-----------------------------------------------------------------------------------------------------"
        write-host "$site : Browser : $browserType : Computer Name :  $sessionComputer"
        write-host "-----------------------------------------------------------------------------------------------------"
        Add-Content $logFile "`n`n-----------------------------------------------------------------------------------------------------"
        Add-Content $logFile "$site : Browser : $browserType : Computer Name :  $sessionComputer"
        Add-Content $logFile  "-----------------------------------------------------------------------------------------------------"
        try{
            $WebResponse = Invoke-WebRequest $site -UserAgent ([Microsoft.PowerShell.Commands.PSUserAgent]::$browserType) 
            Write-Host "SUCCESS!"  -ForegroundColor Green
            Write-Host ("Status Code: " + $WebResponse.StatusCode)  -ForegroundColor Green
            Add-Content $logFile "SUCCESS!" 
            Add-Content $logFile ("Status Code: " + $WebResponse.StatusCode)
            Add-Content $logFile "`n`n"
     
        }catch [System.InvalidOperationException]{ 
            Write-Host "FAILED!" -ForegroundColor Red
            $messageToRecord = "$_.Message"
            Write-Host $messageToRecord   
            Add-Content $logFile "FAILED!"
            Add-Content $logFile $messageToRecord
            Add-Content $logFile "`n`n"

        }
    }
}

function createAndClearFile{
    param (
        [Parameter(Mandatory=$true)]
        [string]$myFile
    )
    if(!(Test-Path $myFile -PathType Leaf)){
        New-Item $myFile -ItemType "file"
    }else{
        Set-Content $myFile ("")
    }
}

#Execution Region------------------------------------------------------------------
if(!($runFromOtherScript)){
    createAndClearFile $logFile
}
Write-Host "---------------------------------"
Write-Host "Testing WSMAN/Session Connection:"
Write-Host "---------------------------------"
Add-Content $logFile "---------------------------------"
Add-Content $logFile "Testing WSMAN/Session Connection:"
Add-Content $logFile "---------------------------------"

if(Test-WSMan $ComputerToConnectFrom -ErrorAction SilentlyContinue){
    Test-WSMan $ComputerToConnectFrom 
    Write-Host "Connection to $ComputerToConnectFrom SUCCESSFUL!" -ForegroundColor Green
    Add-Content $logFile "Connection to $ComputerToConnectFrom SUCCESSFUL!"

    $sess = New-PSSession -ComputerName $ComputerToConnectFrom -Credential $admUser
    $sessionID = $sess.Id
    $sessionComputer = $sess.ComputerName
    Enter-PSSession $sess

    Test-SiteList InternetExplorer
    #Test-SiteList FireFox
    #Test-SiteList Chrome

    if(!($runFromOtherScript)){
        Invoke-Item $logFile
    }

    #[System.Windows.Forms.MessageBox]::Show('External Site Test Complete!','Testing Finished!','OK','Info');
    Write-Host "`n" 
    Write-Host "-----------------------------"
    Write-Host "Exiting Session" 
    Write-Host "-----------------------------" 
    Write-Host "`n" 
    Exit-PSSession
    Remove-PSSession -Id $sessionID 

}else{
    Write-Host "Connection to $ComputerToConnectFrom FAILED!" -ForegroundColor Red
    Write-Host "Is $ComputerToConnectFrom powered on and plugged into the network?"  -ForegroundColor Yellow
    Write-Host "Does $ComputerToConnectFrom have PSRemoting enabled?"  -ForegroundColor Yellow
    Write-Host "Can you ping $ComputerToConnectFrom from $env:computername ?" -ForegroundColor Yellow
    Write-Host "`n"
    Add-Content $logFile "Connection to $ComputerToConnectFrom FAILED!" 
    Add-Content $logFile  "Is $ComputerToConnectFrom powered on and plugged into the network?"
    Add-Content $logFile "Does $ComputerToConnectFrom have PSRemoting enabled?"
    Add-Content $logFile "Can you ping $ComputerToConnectFrom from $env:computername ?"

    Add-Content $logFile "Moving On..."
    Add-Content $logFile "`n"

    if(!($runFromOtherScript)){
        Invoke-Item $logFile
    }
}
sl 'c:'

 