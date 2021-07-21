<###########################################################
#-- Script: PasswordExpiration.ps1
#-- Created: 10/30/2019
#-- Author: Ben Lucas 
#-- DESCRIPTION
#--     Sets all accounts with formats that you choose (ex:???.* and ??.*) to expire or not depeneding on passed in variable. 
#--     Sets account password to chosen sting line 18. Line 19 will allow you to filter by name patterns but needs to be modified 
#--     for specific name schema.
#-- PARAMETER setPasswordExpirationTo
#--     Type anything and hit [Enter] to set passwords to not expire, Type nothing and hit [Enter] to turn on password expiration.
#-- History: Created in August 2019 
#-- BL         1.0.0.0 10/30/2019
############################################################>
$global:setPasswordExpirationTo = $false
$userAnswer = Read-Host("Type 'off' and hit [enter] to turn off expiration, just hit [enter] to skip this: ")
if($userAnswer.Equals("off")) { $global:setPasswordExpirationTo = $true }
Import-Module ActiveDirectory
$NewPwdCred = Get-Credential -Message "Enter the new password in the password field below.  You can ignore the username." -UserName "IGNORE THIS FIELD"
$AllUsers = Get-ADUser -Filter * | Where-Object {$_.name -like '??.*' -or $_.name -like '???.*'}
$AllUsers = $AllUsers | Sort-Object -Property name
#$user
forEach($user in $Allusers){
    Set-ADUser -Identity $user.DistinguishedName -PasswordNeverExpires $global:setPasswordExpirationTo
    Set-ADAccountPassword -Identity $user.DistinguishedName -NewPassword $NewPwdCred.Password
    Write-Host ($user.name + " Password Never Expires: $global:setPasswordExpirationTo")
    Write-Host ($user.name + " Password Reset")
}
