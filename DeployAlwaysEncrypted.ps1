Set-Location c:\
Clear-Host

Install-Module -Name Az -Force -AllowClobber -Verbose

#Prefix for resources
$prefix = "tw"

#Log into Azure
Connect-AzAccount

#Select the correct subscription
Get-AzSubscription -SubscriptionName "MSDN Platforms" | Select-AzSubscription

#Let's create a SQL Server that we will use Always Encrypted with
$Location = "westeurope"
$id = Get-Random -Minimum 1000 -Maximum 9999
$ResourceGroupName = "$prefix-sql-ae-$id"
$SQLServerName = "$prefix-sql-$id"
$SQLDatabaseName = "Hospital"
$SQLAdmin = "sqladmin"
$SQLAdminPassword = ConvertTo-SecureString -String 'P@ssw0rd123!' -AsPlainText -Force
$SQLAdminCredentials = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $SQLAdmin,$SQLAdminPassword

$MyIPAddress = Invoke-RestMethod http://ipinfo.io/json | Select -ExpandProperty ip

#Create a resource group for the SQL Server
$sqlAeRG = New-AzResourceGroup -Name $ResourceGroupName -Location $Location

#Now we need to create a Key Vault to use with the SQL Server
$keyVaultParameters = @{
    Name = "$prefix-key-vault-$id"
    ResourceGroupName = $sqlAeRG.ResourceGroupName
    Location = $location
    EnabledForDiskEncryption = $true
    EnabledForDeployment = $true
    Sku = "Standard"
}
$keyVault = New-AzKeyVault @keyVaultParameters

#Now create an AAD SPN to use with Console App
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
    ServicePrincipalName = $sp.ApplicationId
    PermissionsToKeys = @("wrapKey","unwrapKey","get","recover","sign","verify","list")
}
Set-AzKeyVaultAccessPolicy @accessPolicy

#Grant yourself proper access to the Key Vault
$accessPolicyUPN = @{
    VaultName = $keyVault.VaultName
    UserPrincipalName = "tom@tomwechsler.ch"
    PermissionsToKeys = @("create","wrapKey","unwrapKey","get","recover","sign","verify","list")
}

Set-AzKeyVaultAccessPolicy @accessPolicyUPN

#Create an Azure SQL Server
$sqlServerParameters = @{
    ResourceGroupName = $sqlAeRG.ResourceGroupName
    Location = $Location
    ServerName = $SQLServerName
    SqlAdministratorCredentials = $SQLAdminCredentials
}

$sqlServer = New-AzSqlServer @sqlServerParameters

#Create a Firewall rule allowing you to connect with SSMS
$sqlFirewallParameters = @{
    ResourceGroupName = $sqlAeRG.ResourceGroupName
    ServerName = $sqlServer.ServerName
    FirewallRuleName = "MyIPAddress"
    StartIpAddress = $MyIPAddress
    EndIpAddress = $MyIPAddress
}

$sqlFirewall = New-AzSqlServerFirewallRule @sqlFirewallParameters

#Create a database for the application
$databaseParameters = @{
    ResourceGroupName = $sqlAeRG.ResourceGroupName
    ServerName = $sqlServer.ServerName
    DatabaseName = $SQLDatabaseName
    RequestedServiceObjectiveName = "S0"
    SampleName = "AdventureWorksLT" 
}

$database = New-AzSqlDatabase @databaseParameters

#Now connect to SQL DB with SSMS and configure AE