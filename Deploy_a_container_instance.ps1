Set-Location c:\
Clear-Host

Install-Module -Name Az -Force -AllowClobber -Verbose

#Log into Azure
Connect-AzAccount

#Select the correct subscription
Get-AzSubscription -SubscriptionName "MSDN Platforms" | Select-AzSubscription

#create a resource group
New-AzResourceGroup -Name myResourceGroup -Location "WestEurope"

#run a container in Azure
New-AzContainerGroup -ResourceGroupName myResourceGroup -Name mycontainer -Image mcr.microsoft.com/windows/servercore/iis:nanoserver -OsType Windows -DnsNameLabel tw77-demo-win
#The container's ProvisioningState is initially Creating, but should move to Succeeded within a minute or two

Get-AzContainerGroup -ResourceGroupName myResourceGroup -Name mycontainer

#navigate to its Fqdn in your browser

#Clean up resources
Remove-AzContainerGroup -ResourceGroupName myResourceGroup -Name mycontainer