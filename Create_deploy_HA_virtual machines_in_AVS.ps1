Set-Location c:\
Clear-Host

Install-Module -Name Az -Force -AllowClobber -Verbose

#Log into Azure
Connect-AzAccount

#Select the correct subscription
Get-AzSubscription -SubscriptionName "MSDN Platforms" | Select-AzSubscription

#Create a resource group
New-AzResourceGroup `
   -Name myResourceGroupAvailability `
   -Location WestEurope

#Create a managed availability set
New-AzAvailabilitySet `
   -Location "WestEurope" `
   -Name "myAvailabilitySet" `
   -ResourceGroupName "myResourceGroupAvailability" `
   -Sku aligned `
   -PlatformFaultDomainCount 2 `
   -PlatformUpdateDomainCount 2

#First, set an administrator username and password for the VM
$cred = Get-Credential

#Now create two VMs
for ($i=1; $i -le 2; $i++)
{
    New-AzVm `
        -ResourceGroupName "myResourceGroupAvailability" `
        -Name "myVM$i" `
        -Location "WestEurope" `
        -VirtualNetworkName "myVnet" `
        -SubnetName "mySubnet" `
        -SecurityGroupName "myNetworkSecurityGroup" `
        -PublicIpAddressName "myPublicIpAddress$i" `
        -AvailabilitySetName "myAvailabilitySet" `
        -Credential $cred
}


#If you look at the availability set in the portal by going to Resource Groups > myResourceGroupAvailability > myAvailabilitySet, 
#you should see how the VMs are distributed across the two fault and update domains

#When you create a VM inside a availability set, you need to know what VM sizes are available on the hardware
Get-AzVMSize `
   -ResourceGroupName "myResourceGroupAvailability" `
   -AvailabilitySetName "myAvailabilitySet"

#You can also use Azure Advisor to get more information on how to improve the availability of your VMs


#Clean Up
Remove-AzResourceGroup -Name myResourceGroupAvailability -Force