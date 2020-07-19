#Connect-AzAccount under Add-Ons => Tip from Patrick Gruenauer "PowerShell MVP"

$psISE.CurrentPowerShellTab.AddOnsMenu.Submenus.Add("Connect to Azure",{Connect-AzAccount},"CTRL+ALT+A")