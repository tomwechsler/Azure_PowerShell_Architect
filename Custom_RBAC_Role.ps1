Set-Location C:\Temp
Clear-Host

Install-Module -Name Az -Force -AllowClobber -Verbose

#Log into Azure
Connect-AzAccount

Get-AzProviderOperation "Microsoft.Support/*" | FT Operation, Description -AutoSize

Get-AzRoleDefinition -Name "Reader" | ConvertTo-Json | Out-File C:\Temp\ReaderSupportRole.json

#Open the ReaderSupportRole.json in VSCode

Get-AzSubscription

#In AssignableScopes, add your subscription ID
#Change the Name and Description properties to "Reader Support Tickets" and "View everything in the subscription and also open support tickets."

New-AzRoleDefinition -InputFile "C:\Temp\ReaderSupportRole.json"

#To list all your custom roles
Get-AzRoleDefinition | ? {$_.IsCustom -eq $true} | FT Name, IsCustom

#You can also see the custom role in the Azure portal

#Update a custom role

Get-AzRoleDefinition -Name "Reader Support Tickets" | ConvertTo-Json | Out-File C:\Temp\ReaderSupportRole2.json

#Open the ReaderSupportRole2.json in VSCode
#In Actions, add the operation to create and manage resource group deployments "Microsoft.Resources/deployments/*

Set-AzRoleDefinition -InputFile "C:\Temp\ReaderSupportRole2.json"

$role = Get-AzRoleDefinition "Reader Support Tickets"

$role.Actions.Add("Microsoft.Insights/diagnosticSettings/*/read")

Set-AzRoleDefinition -Role $role

#Delete a custom role
Get-AzRoleDefinition "Reader Support Tickets"

Remove-AzRoleDefinition -Id "22222222-2222-2222-2222-222222222222"