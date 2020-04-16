###########################################################
#-- Script: CompareFolderContentHash.ps1
#-- Created: 4/16/2020
#-- Author: Ben Lucas 
#-- Description: Compares the contents of folders by name, hash, and path 
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
            $inFileHash = get-fileHash $_.FullName -Algorithm MD5
            $OriginalFolderContents.Add(($inFileHash,$_.Name))| Out-Null   
            $inFileHash#Check Output#
        }
        
        Write-host ""
        Write-host "Scanning CopyTo Folder....."
        Write-host ""
        
        gci $destFolder -Recurse  | ForEach-Object{
            $outfileFileHash = get-fileHash $_.FullName -Algorithm MD5
            $CopyToFolderContents.Add(($outfileFileHash,$_.Name)) | Out-Null  
            $outfileFileHash#Check Output
        }
        
        Write-host ""
        Write-host "Comparing....."
        Write-host ""       
        #check for files/folders that are in source folder but not destination and compare HAshes of those that are in both
        foreach($inFile in $OriginalFolderContents){            
            $matched = $false
            foreach($outFile in $CopyToFolderContents){
                #Compare Base Names of files for matches
                if($inFile[1] -eq $outFile[1]){
                    $matched = $true
                    #compare parent folders
                    if($inFile[0].Path.Replace($srcFolder,"") -ne $outFile[0].path.Replace($destFolder,"")){
                        $filesInDifferentFolders.Add($inFile[0].Path)| Out-Null
                        $filesInDifferentFolders.Add($outFile[0].path)| Out-Null
                    }                    
                    if($inFile[0].Hash -ne $outFile[0].Hash){
                        Write-Host "----------------------------------------------------------------------"
                        Write-Host "Some Files Were Different:"  -ForegroundColor Red
                        write-host ("InFile     : " + $inFile[1])
                        write-host ("File Hash: " + $inFile[0].Hash) -ForegroundColor Red
                        write-host ("OutFile    : " + $outFile[1])
                        write-host ("File Hash: " + $outFile[0].Hash) -ForegroundColor Red
                    }else{
                        Write-Host "----------------------------------------------------------------------"
                        Write-Host ("File Size Matched: "+$inFile[1])  -ForegroundColor Green                        
                    }
                    continue                
                }                
            }
            if($matched -eq $false){
                #is item file or folder??
                if($inFile[0].Path -eq $empty){
                    $inFile = ($srcFolder+$inFile+"\").replace(" ","")
                    $filesWithoutMatchesInDestination.Add($inFile)| Out-Null
                    #write-Host ("Output No Match Reached: < "+$inFile+ " >END Output" )#Check Output
                }else{
                    $filesWithoutMatchesInDestination.Add($inFile[0].Path)| Out-Null
                    #write-Host ("Output No Match Reached: < "+$inFile[0].Path + " >END Output" )#Check Output
                }                                
            }            
        }
        
        #check for folders/files not present in source folder that are in destination folder
        foreach($outFile in $CopyToFolderContents){
            $matched = $false
            foreach($inFile in $OriginalFolderContents){
                if($inFile[1] -eq $outFile[1]){
                    $matched = $true
                    continue
                }                
            }
            if($matched -eq $false){
                #is item file or folder??
                if($outFile[0].Path -eq $empty){
                    $outFile = ($destFolder+$outFile+"\").replace(" ","")
                    $filesWithoutMatchesInSource.Add($outFile)| Out-Null
                    #write-Host ("Output No Match Reached: < "+$outFile+ " >END Output" )#Check Output
                }else{
                    $filesWithoutMatchesInSource.Add($outFile[0].Path)| Out-Null
                    #write-Host ("Output No Match Reached: < "+$outFile[0].Path + " >END Output" )#Check Output
                }                                
            }            
        }

        #output Error Results
        if(!$filesInDifferentFolders.Count -eq 0){
            Write-Host "----------------------------------------------------------------------"    
            Write-Host "               Some files weren't in the same place                           " -ForegroundColor Yellow
            Write-Host "----------------------------------------------------------------------"    
            foreach($filePath in $filesInDifferentFolders){write-host $filePath}
        } 
        if(!$filesWithoutMatchesInDestination.Count -eq 0){
            Write-Host "----------------------------------------------------------------------"    
            Write-Host "              Some files didn't exist in destination                           " -ForegroundColor Yellow
            Write-Host "----------------------------------------------------------------------"    
            foreach($file in $filesWithoutMatchesInDestination){write-host $file}
        } 
        if(!$filesWithoutMatchesInSource.Count -eq 0){
            Write-Host "----------------------------------------------------------------------"    
            Write-Host "                Some files didn't exist in source                           " -ForegroundColor Yellow
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

