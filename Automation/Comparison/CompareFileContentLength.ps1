###########################################################
#-- Script: CompareFileContentLength.ps1
#-- Created: 4/16/2020
#-- Author: Ben Lucas 
#-- Description: Compares the contents of folders by name, 
#-- Length of file, and path.Faster than comparing hashes. 
#-- recursively. Reports differences.
#-- History: 
#-- Created 4-16-2020  BL
###########################################################
$srcFolder = "C:\tmp1\"
$destFolder = "C:\tmp2\"

[System.Collections.ArrayList]$OriginalFolderContents = @{}
[System.Collections.ArrayList]$CopyToFolderContents = @{}
[System.Collections.ArrayList]$filesWithoutMatchesInDestination = @{}
[System.Collections.ArrayList]$filesWithoutMatchesInSource = @{}
[System.Collections.ArrayList]$filesInDifferentFolders = @{}

if(Test-Path -Path $srcFolder){
    if(Test-Path -Path $destFolder){
        
        Write-host ""
        Write-host "Scanning Original Folder....."
        Write-host ""
        
        gci $srcFolder -Recurse  | ForEach-Object{
            $OriginalFolderContents.Add($_)| Out-Null   
            #write-host (""+$_.FullName+" #File Length: "+ $_.Length)#Check Output#
        }
        
        Write-host ""
        Write-host "Scanning CopyTo Folder....."
        Write-host ""
        
        gci $destFolder -Recurse  | ForEach-Object{
            $CopyToFolderContents.Add($_) | Out-Null  
            #write-host (""+$_.FullName+" #File Length: "+ $_.Length)#Check Output#
        }
        
        Write-host ""
        Write-host "Comparing....."
        Write-host ""       
        #check for files/folders that are in source folder but not destination and compare lengths of those that are in both
        foreach($inFile in $OriginalFolderContents){            
            $matched = $false
            foreach($outFile in $CopyToFolderContents){
                #Compare Base Names of files for matches
                if($inFile.name -eq $outFile.name){
                    $matched = $true
                    #compare parent folders
                    if($inFile.FullName.Replace($srcFolder,"") -ne $outFile.FullName.Replace($destFolder,"")){
                        $filesInDifferentFolders.Add($inFile.FullName)| Out-Null
                        $filesInDifferentFolders.Add($outFile.FullName)| Out-Null
                    }                    
                    if($inFile.Length -ne $outFile.Length){
                        Write-Host "----------------------------------------------------------------------"
                        Write-Host "Some Files Were Different:"  -ForegroundColor Red
                        write-host ("InFile Name   : " + $inFile.Name)
                        write-host ("InFile Length : " + $inFile.Length)
                        write-host ("OutFile Name  : " + $outFile.Name)
                        write-host ("OutFile Length: " + $outFile.Length)
                    }else{
                        Write-Host "----------------------------------------------------------------------"
                        Write-Host ("File Size Matched: "+$inFile.Name)  -ForegroundColor Green                        
                    }
                    continue
                }                
            }
            if($matched -eq $false){
                $filesWithoutMatchesInDestination.Add($inFile.FullName)| Out-Null                
            }            
        }

        #check for folders/files not present in source folder that are in destination folder
        foreach($outFile in $CopyToFolderContents){
            $matched = $false
            foreach($inFile in $OriginalFolderContents){
                if($inFile.BaseName -eq $outFile.BaseName){
                    $matched = $true
                    continue
                }                
            }
            if($matched -eq $false){
                $filesWithoutMatchesInSource.Add($outFile.FullName)| Out-Null                
            }            
        }

        #output Error Results
        if(!$filesInDifferentFolders.Count -eq 0){
            Write-Host "----------------------------------------------------------------------"    
            Write-Host "              Some files weren't in the same place                           " -ForegroundColor Yellow
            Write-Host "----------------------------------------------------------------------"    
            foreach($filePath in $filesInDifferentFolders){write-host $filePath}
        } 
        if(!$filesWithoutMatchesInDestination.Count -eq 0){
            Write-Host "----------------------------------------------------------------------"    
            Write-Host "             Some files didn't exist in destination                           " -ForegroundColor Yellow
            Write-Host "----------------------------------------------------------------------"    
            foreach($file in $filesWithoutMatchesInDestination){write-host $file}
        } 
        if(!$filesWithoutMatchesInSource.Count -eq 0){
            Write-Host "----------------------------------------------------------------------"    
            Write-Host "               Some files didn't exist in source                           " -ForegroundColor Yellow
            Write-Host "----------------------------------------------------------------------"    
            foreach($file in $filesWithoutMatchesInSource){write-host $file}
        } 
        if(($filesInDifferentFolders.Count -eq 0) -and ($filesWithoutMatchesInDestination.Count -eq 0) -and ($filesWithoutMatchesInSource.Count -eq 0)){
            Write-Host "----------------------------------------------------------------------"    
            Write-Host "                     <-ALL FILES MATCHED!->                           " -ForegroundColor Green
        }

        Write-Host "----------------------------------------------------------------------"    
        Write-Host "                    <-GOODBYE, Hit Any Key->                            " -ForegroundColor Yellow
        Write-Host "----------------------------------------------------------------------"    
        Read-Host 
    }else{Write-Host "I can't find the copied folder.  Please re-enter the location and try again." -ForegroundColor Red}  
}else{Write-Host "I can't find the original folder  Please re-enter the location and try again." -ForegroundColor Red}

