Set-Location c:\
Clear-Host

Install-Module -Name Az -Force -AllowClobber -Verbose

#Prefix for resources
$prefix = "tw"

#Basic variables
$location = "westeurope"
$id = Get-Random -Minimum 1000 -Maximum 9999

#Log into Azure
Connect-AzAccount

#Select the correct subscription
Get-AzSubscription -SubscriptionName "MSDN Platforms" | Select-AzSubscription

#Create a resource group
New-AzResourceGroup -ResourceGroupName myResourceGroup -Location $location

#Create a route table
$routeTablePublic = New-AzRouteTable `
  -Name 'myRouteTablePublic' `
  -ResourceGroupName myResourceGroup `
  -location $location

#Create a route
Get-AzRouteTable `
  -ResourceGroupName "myResourceGroup" `
  -Name "myRouteTablePublic" `
  | Add-AzRouteConfig `
  -Name "ToPrivateSubnet" `
  -AddressPrefix 10.0.1.0/24 `
  -NextHopType "VirtualAppliance" `
  -NextHopIpAddress 10.0.2.4 `
 | Set-AzRouteTable

#create a virtual network and subnet
$virtualNetwork = New-AzVirtualNetwork `
  -ResourceGroupName myResourceGroup `
  -Location $location `
  -Name myVirtualNetwork `
  -AddressPrefix 10.0.0.0/16

#Create three subnets
$subnetConfigPublic = Add-AzVirtualNetworkSubnetConfig `
  -Name Public `
  -AddressPrefix 10.0.0.0/24 `
  -VirtualNetwork $virtualNetwork

$subnetConfigPrivate = Add-AzVirtualNetworkSubnetConfig `
  -Name Private `
  -AddressPrefix 10.0.1.0/24 `
  -VirtualNetwork $virtualNetwork

$subnetConfigDmz = Add-AzVirtualNetworkSubnetConfig `
  -Name DMZ `
  -AddressPrefix 10.0.2.0/24 `
  -VirtualNetwork $virtualNetwork

#Associate the myRouteTablePublic route table to the Public subnet
Set-AzVirtualNetworkSubnetConfig `
  -VirtualNetwork $virtualNetwork `
  -Name 'Public' `
  -AddressPrefix 10.0.0.0/24 `
  -RouteTable $routeTablePublic | `
Set-AzVirtualNetwork

#Create an NVA => NVA is a VM that performs a network function, such as routing, firewalling, or WAN optimization

# Retrieve the virtual network object into a variable.
$virtualNetwork=Get-AzVirtualNetwork `
  -Name myVirtualNetwork `
  -ResourceGroupName myResourceGroup

# Retrieve the subnet configuration into a variable.
$subnetConfigDmz = Get-AzVirtualNetworkSubnetConfig `
  -Name DMZ `
  -VirtualNetwork $virtualNetwork

# Create the network interface.
$nic = New-AzNetworkInterface `
  -ResourceGroupName myResourceGroup `
  -Location $location `
  -Name 'myVmNva' `
  -SubnetId $subnetConfigDmz.Id `
  -EnableIPForwarding

#Create a NVA VM
# Create a credential object.
$cred = Get-Credential -Message "Enter a username and password for the VM."

# Create a NVA VM configuration.
$vmConfig = New-AzVMConfig `
  -VMName 'myVmNva' `
  -VMSize Standard_B1s | `
  Set-AzVMOperatingSystem -Windows `
    -ComputerName 'myVmNva' `
    -Credential $cred | `
  Set-AzVMSourceImage `
    -PublisherName MicrosoftWindowsServer `
    -Offer WindowsServer `
    -Skus 2016-Datacenter `
    -Version latest | `
  Add-AzVMNetworkInterface -Id $nic.Id

#Create the NVA VM
$vmNva = New-AzVM `
  -ResourceGroupName myResourceGroup `
  -Location $location `
  -VM $vmConfig `
  -AsJob

Get-Job

#Create two VMs in the virtual network so you can validate that traffic
New-AzVm `
  -ResourceGroupName "myResourceGroup" `
  -Location $location `
  -VirtualNetworkName "myVirtualNetwork" `
  -SubnetName "Public" `
  -ImageName "Win2016Datacenter" `
  -Name "myVmPublic" `
  -AsJob

New-AzVm `
  -ResourceGroupName "myResourceGroup" `
  -Location $location `
  -VirtualNetworkName "myVirtualNetwork" `
  -SubnetName "Private" `
  -ImageName "Win2016Datacenter" `
  -Name "myVmPrivate"

#Route traffic through an NVA
Get-AzPublicIpAddress `
  -Name myVmPrivate `
  -ResourceGroupName myResourceGroup `
  | Select IpAddress

#Create a remote desktop session with the myVmPrivate VM from your local computer.
mstsc /v:40.118.0.239

#Enable ICMP through the Windows firewall
New-NetFirewallRule -DisplayName "Allow ICMPv4-In" -Protocol ICMPv4

#From a command prompt on the myVmPrivate VM, remote desktop to the myVmNva
mstsc /v:myvmnva

#To enable IP forwarding within the operating system, enter the following command in PowerShell from the myVmNva VM
Set-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters -Name IpEnableRouter -Value 1

#=>Restart the myVmNva VM

#While still connected to the myVmPrivate VM, create a remote desktop session to the myVmPublic VM
mstsc /v:myVmPublic

#Enable ICMP through the Windows firewall by entering the following command from PowerShell on the myVmPublic VM
New-NetFirewallRule –DisplayName "Allow ICMPv4-In" –Protocol ICMPv4

#To test routing of network traffic to the myVmPrivate VM from the myVmPublic VM
tracert myVmPrivate

#You can see that the first hop is 10.0.2.4, which is the NVA's private IP address

#Close the remote desktop session to the myVmPublic VM, which leaves you still connected to the myVmPrivate VM
tracert myVmPublic

#Clean up resources
Remove-AzResourceGroup -Name myResourceGroup -Force