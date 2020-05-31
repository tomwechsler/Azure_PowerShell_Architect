Set-Location c:\
Clear-Host

Install-Module -Name Az -Force -AllowClobber -Verbose

#Log into Azure
Connect-AzAccount

#Select the correct subscription
Get-AzSubscription -SubscriptionName "MSDN Platforms" | Select-AzSubscription

# Basic variables
$webappname="mywebapp$(Get-Random)"
$location="West Europe"

# Create a resource group.
New-AzResourceGroup -Name myResourceGroup -Location $location

# Create an App Service plan in Free tier.
New-AzAppServicePlan -Name $webappname -Location $location `
-ResourceGroupName myResourceGroup -Tier Free

# Create a web app.
New-AzWebApp -Name $webappname -Location $location `
-AppServicePlan $webappname -ResourceGroupName myResourceGroup

# Upgrade App Service plan to Standard tier (minimum required by deployment slots)
Set-AzAppServicePlan -Name $webappname -ResourceGroupName myResourceGroup `
-Tier Standard

#Create a deployment slot with the name "staging".
New-AzWebAppSlot -Name $webappname -ResourceGroupName myResourceGroup `
-Slot staging

#Change the some infos in the staging slot

# Swap the verified/warmed up staging slot into production.
Switch-AzWebAppSlot -Name $webappname -ResourceGroupName myResourceGroup `
-SourceSlotName staging -DestinationSlotName production

#Clean Up
Remove-AzResourceGroup -Name myResourceGroup -Force