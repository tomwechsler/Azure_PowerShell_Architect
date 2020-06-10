Set-Location c:\
Clear-Host

Install-Module -Name Az -Force -AllowClobber -Verbose

#Log into Azure
Connect-AzAccount

#Select the correct subscription
Get-AzSubscription -SubscriptionName "MSDN Platforms" | Select-AzSubscription
Get-AzContext

#Create a resource group
New-AzResourceGroup `
  -ResourceGroupName myResourceGroup `
  -Location westeurope

#Create a Virtual Network
$virtualNetwork = New-AzVirtualNetwork `
  -ResourceGroupName myResourceGroup `
  -Location westeurope `
  -Name myVirtualNetwork `
  -AddressPrefix 10.0.0.0/16

#Add a Subnet
$subnetConfig = Add-AzVirtualNetworkSubnetConfig `
  -Name mySubnet `
  -AddressPrefix 10.0.0.0/24 `
  -PrivateEndpointNetworkPoliciesFlag "Disabled" `
  -VirtualNetwork $virtualNetwork

#Associate the Subnet to the Virtual Network
$virtualNetwork | Set-AzVirtualNetwork

#Create a VM in the Virtual Network
New-AzVm `
    -ResourceGroupName "myResourceGroup" `
    -Name "myVm" `
    -Location "westeurope" `
    -VirtualNetworkName "MyVirtualNetwork" `
    -SubnetName "mySubnet" `
    -SecurityGroupName "myNetworkSecurityGroup" `
    -PublicIpAddressName "myPublicIpAddress" `
    -OpenPorts 80,3389 `
    -AsJob

Get-Job

#Create a logical SQL server
$adminSqlLogin = "SqlAdmin"
$password = "P@ssw0rd123!"

$server = New-AzSqlServer -ResourceGroupName "myResourceGroup" `
    -ServerName "twsqlsrv1975" `
    -Location "westeurope" `
    -SqlAdministratorCredentials $(New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $adminSqlLogin, $(ConvertTo-SecureString -String $password -AsPlainText -Force))

New-AzSqlDatabase  -ResourceGroupName "myResourceGroup" `
    -ServerName "twsqlsrv1975"`
    -DatabaseName "myda"`
    -RequestedServiceObjectiveName "S0" `
    -SampleName "AdventureWorksLT"

#Create Private Endpoint for the server in your Virtual Network
$privateEndpointConnection = New-AzPrivateLinkServiceConnection -Name "myConnection" `
  -PrivateLinkServiceId $server.ResourceId `
  -GroupId "sqlServer" 
 
$virtualNetwork = Get-AzVirtualNetwork -ResourceGroupName  "myResourceGroup" -Name "MyVirtualNetwork"  
 
$subnet = $virtualNetwork `
  | Select -ExpandProperty subnets `
  | Where-Object  {$_.Name -eq 'mysubnet'}  
 
$privateEndpoint = New-AzPrivateEndpoint -ResourceGroupName "myResourceGroup" `
  -Name "myPrivateEndpoint" `
  -Location "westeurope" `
  -Subnet  $subnet `
  -PrivateLinkServiceConnection $privateEndpointConnection

#Create a Private DNS Zone for SQL Database domain, create an association link with the Virtual Network 
#and create a DNS Zone Group to associate the private endpoint with the Private DNS Zone
$zone = New-AzPrivateDnsZone -ResourceGroupName "myResourceGroup" `
  -Name "privatelink.database.windows.net" 
 
$link  = New-AzPrivateDnsVirtualNetworkLink -ResourceGroupName "myResourceGroup" `
  -ZoneName "privatelink.database.windows.net"`
  -Name "mylink" `
  -VirtualNetworkId $virtualNetwork.Id  

$config = New-AzPrivateDnsZoneConfig -Name "privatelink.database.windows.net" -PrivateDnsZoneId $zone.ResourceId

$privateDnsZoneGroup = New-AzPrivateDnsZoneGroup -ResourceGroupName "myResourceGroup" `
 -PrivateEndpointName "myPrivateEndpoint" -name "MyZoneGroup" -PrivateDnsZoneConfig $config

#Connect to the VM from the internet
Get-AzPublicIpAddress `
  -Name myPublicIpAddress `
  -ResourceGroupName myResourceGroup `
  | Select IpAddress

mstsc /v:104.40.252.173

#In the VM open PowerShell
nslookup twsqlsrv1975.privatelink.database.windows.net

#Now you can connect to the Server with the SQL Server Management Studio

#Clean Up
Remove-AzResourceGroup -Name myResourceGroup -Force