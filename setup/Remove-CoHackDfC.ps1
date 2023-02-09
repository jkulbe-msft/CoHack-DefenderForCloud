Write-Host "Removing the role assignment"
Get-AzRoleAssignment -RoleDefinitionName "Limited Security Reader" | Remove-AzRoleAssignment
	
Write-Host "Removing the role"
Remove-AzRoleDefinition -Name "Limited Security Reader" -Force
	
Write-Host "Deleting the Resource Group"
Remove-azresourcegroup -Name "CoHackDfC" -Force
	
Write-Host "Deleting User"
if (!(Get-Module Microsoft.Graph -ListAvailable))
{
    Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted
    Install-Module Microsoft.Graph
}
	
Connect-MgGraph -Scopes 'User.ReadWrite.All','Directory.Read.All','Domain.Read.All'
remove-MgUser -UserId "CoHackDfCUser@azure4lab.tk"

Write-Host "Disabling Defender for server"
Set-AzSecurityPricing -Name "VirtualMachines" -PricingTier "free"