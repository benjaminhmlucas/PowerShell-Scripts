<###########################################################
#-- Script: PasswordExpiration.ps1
#-- Created: 10/30/2019
#-- Author: Ben Lucas 
#-- DESCRIPTION
#--     Sets all accounts with formats that you choose (ex:???.* and ??.*) to expire or not depeneding on passed in variable.
#--     Line 18 will allow you to filter by name patterns but needs to be modified for specific name schema
#-- PARAMETER setPasswordExpirationTo
#--     type `$true' to set passwords to not expire, Hit Enter to turn on password expiration.
#-- History: Created in August 2019 
#-- BL         1.0.0.0 10/30/2019
############################################################>
param (
    [Parameter(
    HelpMessage = "'`$true' to set passwords to not expire, Hit Enter to turn on password expiration.")]
    [bool]$setPasswordNeverExpires = $false
)
Import-Module activedirectory
$AllUsers = Get-ADUser -Filter * <#| Where-Object {$_.name -like '??.*' -or $_.name -like '???.*'}#>
$AllUsers = $AllUsers | Sort-Object -Property name
#$user
forEach($user in $Allusers){
    Set-ADUser -Identity $user.DistinguishedName -PasswordNeverExpires $setPasswordNeverExpires
    Write-Host ($user.name + " Password Expiration Enabled: $setPasswordNeverExpires")
}
