###########################################################
#-- Script: Test-ExternalSiteTest-Multiple.ps1
#-- Created: 8/7/2018
#-- Author: Ben Lucas 
#-- Description: Opens script: Test-ExternalSiteTest-Single.ps1 and runs it on a chosen workstations, this is used for Testing External
#-- Website connection from a domain server to a chosen workstations.  Please Set lines 15-18 and line 19 between <>'s-->
#-- History: Created in October 2019 
#-- BL         1.0.0.0 10/10/2019
#-- BL         1.0.0.1 10/22/2019
#-- BL         1.0.0.2 10/29/2019  update for github 
###########################################################

Add-Type -AssemblyName System.Windows.Forms

#set Variables--------------------------------------- Please Set lines 15-18 and line 19 between <>'s-->
$logFile = "C:\<Your folder location>\ExternalSiteTestLog.txt" #file Path must exists !!
$scriptLocation = 'C:\<Your folder location>\' #location of script to run in the loop, file Path must exists
$admUserName = "<domain>\<user name>"
$UserPwd = ConvertTo-SecureString -String "<Your Password>" -AsPlainText -Force
$admUser = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $admUserName,$UserPwd
$workstationsToTestList = Get-ADComputer -Filter * | Where-Object {$_.name -like "*<workstation names>*" <#-or $_.name -like 'win732'#>} #this variable determines which VMs are used for the test

#Function Region------------------------------------

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

#Execution Region------------------------------------

createAndClearFile $logFile

forEach($workstationToTest in $workstationsToTestList){  
    sl $scriptLocation
    .\Test-ExternalSiteTest-Single.ps1 -ComputerToConnectFrom $workstationToTest.Name -runFromOtherScript $true
}

Invoke-Item $logFile
sl 'c:'
[System.Windows.Forms.MessageBox]::Show('Testing Complete!','All Done','OK','Info');

