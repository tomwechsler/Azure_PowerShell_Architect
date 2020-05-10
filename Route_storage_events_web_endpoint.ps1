Set-Location c:\
Clear-Host

Install-Module -Name Az -Force -AllowClobber -Verbose

#Basic variables
$prefix = "tw"
$location = "westeurope"
$id = Get-Random -Minimum 1000 -Maximum 9999

#Log into Azure
Connect-AzAccount

#Select the correct subscription
Get-AzSubscription -SubscriptionName "MSDN Platforms" | Select-AzSubscription

#Azure Event Grid is an eventing service for the cloud. In this Video, you use 
#Azure PowerShell to subscribe to Blob storage events, trigger an event, and view the result.
#Typically, you send events to an endpoint that processes the event data and takes actions. 
#However, to simplify this article, you send the events to a web app that collects and displays the messages

#Create a resource group
$resourceGroup = "gridResourceGroup"
New-AzResourceGroup -Name $resourceGroup -Location $location

#Create a storage account
$storageName = "$($prefix)sa$id"
$storageAccount = New-AzStorageAccount -ResourceGroupName $resourceGroup `
  -Name $storageName `
  -Location $location `
  -SkuName Standard_LRS `
  -Kind BlobStorage `
  -AccessTier Hot

$ctx = $storageAccount.Context

#Create a message endpoint
$sitename="twcontosotom75"

New-AzResourceGroupDeployment `
  -ResourceGroupName $resourceGroup `
  -TemplateUri "https://raw.githubusercontent.com/Azure-Samples/azure-event-grid-viewer/master/azuredeploy.json" `
  -siteName $sitename `
  -hostingPlanName viewerhost

#Enable Event Grid resource provider
Register-AzResourceProvider -ProviderNamespace Microsoft.EventGrid
Get-AzResourceProvider -ProviderNamespace Microsoft.EventGrid

#Subscribe to your storage account
$storageId = (Get-AzStorageAccount -ResourceGroupName $resourceGroup -AccountName $storageName).Id
$endpoint="https://$sitename.azurewebsites.net/api/updates"

New-AzEventGridSubscription `
  -EventSubscriptionName gridBlobQuickStart `
  -Endpoint $endpoint `
  -ResourceId $storageId

#Trigger an event from Blob storage
$containerName = "gridcontainer"
New-AzStorageContainer -Name $containerName -Context $ctx

echo $null >> gridTestFile.txt

Set-AzStorageBlobContent -File gridTestFile.txt -Container $containerName -Context $ctx -Blob gridTestFile.txt

#Clean up resources
Remove-AzResourceGroup -Name $resourceGroup -Force