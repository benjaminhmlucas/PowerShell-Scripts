<###########################################################
#-- Script: PasswordExpiration.ps1
#-- Created: 10/30/2019
#-- Author: Ben Lucas 
#-- DESCRIPTION
#--     Sets all accounts with formats that you choose (ex:???.* and ??.*) to expire or not depeneding on passed in variable. 
#--     Sets account password to chosen sting line 16. Line 22 will allow you to filter by name patterns but needs to be modified 
#--     for specific name schema.
#-- PARAMETER setPasswordExpirationTo
#--     Type anything and hit [Enter] to set passwords to not expire, Type nothing and hit [Enter] to turn on password expiration.
#-- History: Created in August 2019 
#-- BL         1.0.0.0 10/30/2019
############################################################>
param (
    [Parameter(Mandatory=$true,
    HelpMessage = "Type anything and hit [Enter] to set passwords to not expire, Type nothing and hit [Enter] to turn on password expiration.")]
    [bool]$setPasswordExpirationTo
)

Import-Module ActiveDirectory
$DefaultPwd = ConvertTo-SecureString -String "<New Password to set" -AsPlainText -Force
$AllUsers = Get-ADUser -Filter * | Where-Object {$_.name -like '??.*' -or $_.name -like '???.*'}
$AllUsers = $AllUsers | Sort-Object -Property name
#$user
forEach($user in $Allusers){
    Set-ADUser -Identity $user.DistinguishedName -PasswordNeverExpires $setPasswordExpirationTo 
    Set-ADAccountPassword -Identity $user.DistinguishedName -NewPassword $DefaultPwd
    Write-Host ($user.name + " Password Never Expires: $setPasswordExpirationTo")
    Write-Host ($user.name + " Password Reset")
}
