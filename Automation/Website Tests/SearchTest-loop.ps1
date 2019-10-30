###########################################################
#-- Script: SearchTest-loop.ps1
#-- Created: 10/30/2019
#-- Author: Ben Lucas 
#-- Description: searches for $searchTerm using bing or google.  You can have it open as many tabs 
#-- as you want, Any Edge or Internet Explorer windows will be closed at the end of the script.
#-- History: Created in August 2019 
#-- BL         1.0.0.0 10/30/2019
###########################################################
$counter = 1
$numberOfTabs = 30 #set the number of tabes you want to open
$searchTerm = "it doesn't matter" #term to search for
$searchToUse = "Bing" #--for google change to "Google"

while($counter -le $numberOfTabs){  
     searchSite -SearchFor ($searchTerm+$counter) -Use "Bing"
     $counter = ($counter + 1)
}


$Edges = Get-Process | Where-Object{$_.Name -like "MicrosoftEdge"}
$Explorers = Get-Process | Where-Object{$_.Name -like "iexplore"}
forEach($edgeProcess in $Edges){
    Stop-Process -Name $edgeProcess.Name
}
forEach($explorerProcess in $Explorers){
    Stop-Process -Name $explorerProcess.Name
}    

function searchSite{
        [CmdletBinding()]
    Param(
	    [Parameter(Mandatory=$True,Position=0)]
	    [String]$SearchFor,
	
	    [Parameter(Mandatory=$True,Position=1)]
	    [String]$Use
    )

    $ErrorActionPreference = "SilentlyContinue"
    If ($Error) {$Error.Clear()}
    $SearchFor = $SearchFor.Trim()
    If (!($SearchFor)) {
	    Write-Host
	    Write-Host "Text That You Wish To Search For Has Not Been Entered." -ForeGroundColor "Yellow"
	    Write-Host "Execution of the Script Has been Ternimated." -ForeGroundColor "Yellow"
	    Write-Host
	    Exit
    }
    $Use = $Use.Trim()
    If (!($Use)) {
	    Write-Host
	    Write-Host "Search Engine To Use Has Not Been Specified." -ForeGroundColor "Yellow"
	    Write-Host "Execution of the Script Has been Ternimated." -ForeGroundColor "Yellow"
	    Write-Host
	    Exit
    }
    $SearchFor = $SearchFor -Replace "\s+", " "
    $SearchFor = $SearchFor -Replace " ", "+"

    Switch ($Use) {
	    "Google" {
		    # -- "Use Google To Search"
		    $Query = "https://www.google.com/search?q=$SearchFor"
	    }
	    "Bing" {
		    # -- "Use Bing Search Engine To Search"
		    $Query = "http://www.bing.com/search?q=$SearchFor"
	    }
	    Default {$Query = "No Search Engine Specified"}
    }
    If ($Query -NE "Microsoft-Edge") {
	    ## -- Detect the Default Web Browser
	    start microsoft-edge:$Query
        $IE=new-object -com internetexplorer.application
        $IE.navigate2($Query)
        $IE.visible=$true
    }
    Else {
	    Write-Host
	    Write-Host $Query -ForeGroundColor "Yellow" 
	    Write-Host "Execution of the Script Has been Ternimated." -ForeGroundColor "Yellow"
	    Write-Host
    }
}