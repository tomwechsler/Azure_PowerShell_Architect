Set-Location c:\
Clear-Host

Install-Module -Name Az -Force -AllowClobber -Verbose

#Prefix for resources
$prefix = "tw"

#Log into Azure
Connect-AzAccount

#Select the correct subscription
Get-AzSubscription -SubscriptionName "MSDN Platforms" | Select-AzSubscription

#Let's create a SQL VM that we will apply TDE to
$Location = "westeurope"
$id = Get-Random -Minimum 1000 -Maximum 9999
$ResourceGroupName = "$prefix-sql-vm-$id"
$SQLServerName = "$prefix-sql-$id"

#Create the resource group for the SQL VM
$sqlvmRG = New-AzResourceGroup -Name $ResourceGroupName -Location $Location

#Deploy the SQL VM using an ARM template
$templateParameters = @{
    adminUsername = "winadmin"
    adminPassword = 'P@ssw0rd123!'
    location = $Location
    dnsName = "sql$prefix$id"
    vmName = $SQLServerName
}

New-AzResourceGroupDeployment -Name "tw-sql-vm" -ResourceGroupName $sqlvmRG.ResourceGroupName -TemplateParameterObject $templateParameters -TemplateFile .\sql-vm.json -Mode Incremental

#Now we need to create a Key Vault to use with the SQL VM
$keyVaultParameters = @{
    Name = "$prefix-key-vault-$id"
    ResourceGroupName = $sqlvmRG.ResourceGroupName
    Location = $location
    EnabledForDiskEncryption = $true
    EnabledForDeployment = $true
    Sku = "Standard"
}
$keyVault = New-AzKeyVault @keyVaultParameters

#And add a key that the server will be used for TDE
$sqlkey = Add-AzKeyVaultKey -VaultName $keyVault.VaultName -Name "$prefix-sql-key" -Destination 'Software'

#Now create an AAD SPN to use with SQL VM
Import-Module Az.Resources # Imports the PSADPasswordCredential object
$credProps = @{
    StartDate = Get-Date
    EndDate = (Get-Date -Year 2024)
    Password = '9MPG7j2MAH3fEveE58vxxg0ghjo9sEutitv9jBeyjfqTLpb9sGBhXQSY9yn2' #Or generate your own, avoid special characters
}
$credentials = New-Object Microsoft.Azure.Commands.ActiveDirectory.PSADPasswordCredential -Property $credProps
$sp = New-AzAdServicePrincipal -DisplayName $SQLServerName -PasswordCredential $credentials

#Grant the SPN access to the Key Vault
$accessPolicy = @{
    VaultName = $keyVault.VaultName
    ObjectId = $sp.Id
    PermissionsToKeys = @("wrapKey","unwrapKey","get","recover")
}
Set-AzKeyVaultAccessPolicy @accessPolicy

#Now enable Key Vault integration in the portal using the following values
#Key Vault URL
Write-Output $keyVault.VaultUri
#Principal Name
Write-Output $sp.ApplicationId.Guid
#Principal Secret
Write-Output $credentials.Password
#Credential name is twsqlcred

#And update SQL with the proper key info
Write-Output $sqlkey.Name

