Set-Location c:\
Clear-Host

Install-Module -Name Az -Force -AllowClobber -Verbose

#Basic variables
$location = "westeurope"
$RG1 = "tw-rg11"

#Log into Azure
Connect-AzAccount

#Select the correct subscription
Get-AzSubscription -SubscriptionName "MSDN Platforms" | Select-AzSubscription

#Create a resource group
New-AzResourceGroup -Name $RG1 -Location $location

#First, create a subnet
$subnet = New-AzVirtualNetworkSubnetConfig `
    -Name "mySubnet" `
    -AddressPrefix "192.168.1.0/24"

#Create a virtual network
$vnet = New-AzVirtualNetwork -ResourceGroupName $RG1 `
    -Location $location `
    -Name "myVnet" `
    -AddressPrefix "192.168.0.0/16" `
    -Subnet $Subnet

#First, create a network security group rule
$rdp = New-AzNetworkSecurityRuleConfig `
    -Name 'Allow-RDP-All' `
    -Description 'Allow RDP' `
    -Access Allow `
    -Protocol Tcp `
    -Direction Inbound `
    -Priority 300 `
    -SourceAddressPrefix * `
    -SourcePortRange * `
    -DestinationAddressPrefix * `
    -DestinationPortRange 3389

#Create a network security group
$nsg = New-AzNetworkSecurityGroup `
    -ResourceGroupName $RG1 `
    -Location $location `
    -Name "myNsg" `
    -SecurityRules $rdp

#Associate the network security group to the mySubnet
Set-AzVirtualNetworkSubnetConfig `
    -VirtualNetwork $vnet `
    -Name 'mySubnet' `
    -AddressPrefix "192.168.1.0/24" `
    -NetworkSecurityGroup $nsg

#Create a public IP address
$publicIp = New-AzPublicIpAddress `
    -ResourceGroupName $RG1 `
    -Name 'myPublicIp' `
    -location $location `
    -AllocationMethod Dynamic

#Create a network interface
$nic = New-AzNetworkInterface `
    -ResourceGroupName $RG1 `
    -Name "myNic" `
    -Location $location `
    -SubnetId $vnet.Subnets[0].Id `
    -PublicIpAddressId $publicIp.Id `
    -EnableAcceleratedNetworking

#Set your VM credentials
$cred = Get-Credential

#First, define your VM
$vmConfig = New-AzVMConfig -VMName "myVm" -VMSize "Standard_D4s_v3"

#Create the rest of your VM configuration
$vmConfig = Set-AzVMOperatingSystem -VM $vmConfig `
    -Windows `
    -ComputerName "myVM" `
    -Credential $cred `
    -ProvisionVMAgent `
    -EnableAutoUpdate
$vmConfig = Set-AzVMSourceImage -VM $vmConfig `
    -PublisherName "MicrosoftWindowsServer" `
    -Offer "WindowsServer" `
    -Skus "2016-Datacenter" `
    -Version "latest"

#Attach the network interface
$vmConfig = Add-AzVMNetworkInterface -VM $vmConfig -Id $nic.Id

#Finally, create your VM
New-AzVM -VM $vmConfig -ResourceGroupName $RG1 -Location $location

#Once you create the VM in Azure, connect to the VM and confirm that the driver is installed in Windows

