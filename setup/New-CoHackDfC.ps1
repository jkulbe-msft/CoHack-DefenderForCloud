# run from CloudShell
[CmdletBinding()]
param (
    $ResourceGroup = 'CoHackDfC',

    $Location = 'eastus',

    $UserName = 'CoHackDfCUser'

)
$subscription = (Get-AzContext).Subscription
# quick and dirty password generator, not perfect, any character will be picked only once
$Password = (("ABCDEFGHKLMNOPRSTUVWXYZabcdefghiklmnoprstuvwxyz0123456789$!#".tochararray() | Get-Random -Count 9) -join '') + "dC!"

# register resource provider for Defender for Cloud
Write-Host "Registering Defender for Cloud resource provider"
Get-AzResourceProvider -ProviderNamespace Microsoft.Security | Where-Object RegistrationState -ne Registered | Register-AzResourceProvider

while (Get-AzResourceProvider -ProviderNamespace Microsoft.Security | Where-Object RegistrationState -ne Registered)
{
    Write-Host "Waiting for resource provider registration"
    Start-Sleep 10
}

# create Limited Security Reader role
Write-Host "Deploying ARM template for Limited Security Reader role"
New-AzDeployment -TemplateFile .\LimitedSecurityReader_ARM.json -TemplateParameterFile .\LimitedSecurityReader_ARM.parameters.json -Location $Location

# create RG with a VM and Log Analytics workspace
Write-Host "Deploying ARM template for resource group $ResourceGroup"
New-AzResourceGroup -Name $ResourceGroup -Location $Location -Force
New-AzResourceGroupDeployment -ResourceGroupName $ResourceGroup -TemplateFile .\CohackDfCRG.json -TemplateParameterFile .\CohackDfCRG.parameters.json -adminPassword (ConvertTo-SecureString -String $Password -AsPlainText -Force)

# create a user with limited permissions

# Install AzureAD module
# Install-Module AzureAD
# Import-Module AzureAD

Write-Host "Creating User"
if (!(Get-Module Microsoft.Graph -ListAvailable))
{
    Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted
    Install-Module Microsoft.Graph
}

Connect-MgGraph -Scopes 'User.ReadWrite.All','Directory.Read.All','Domain.Read.All' -UseDeviceAuthentication
$UPN = $username + '@' + (Get-MgDomain | ? IsDefault).Id
$PasswordProfile = @{
  Password = $Password
  ForceChangePasswordNextSignIn = $false
}
$User = New-MgUser -DisplayName $UserName -PasswordProfile $PasswordProfile -UserPrincipalName $UPN -AccountEnabled -MailNickName "$UserName" -UsageLocation 'US'

Write-Host "Created user $UPN with password $Password"

# RBAC
Write-Host "Assigning contributor rights for user $UPN on RG $ResourceGroup"
New-AzRoleAssignment -ObjectId $User.Id -RoleDefinitionName "Contributor" -ResourceGroupName $ResourceGroup

Write-Host "Assigning Limited Security Reader rights for user $UPN on subscription $($subscription.name)"
New-AzRoleAssignment -ObjectId $User.Id -RoleDefinitionName "Limited Security Reader" -Scope "/subscriptions/$($subscription.id)"

# enable Defender for Cloud standard pricing tier
Write-Host "Enabling Defender for Cloud Standard Pricing"
Set-AzSecurityPricing -Name "VirtualMachines" -PricingTier "Standard"

# enable autoprovisioning 
Write-Host "Enabling Defender for Cloud Autoprovisioning"
$laws = Get-AzResource -Name "CoHackDfC-laws"
Set-AzSecurityWorkspaceSetting -Name "default" -Scope "/subscriptions/$($subscription.id)" -WorkspaceId $laws.ResourceId
Set-AzSecurityAutoProvisioningSetting -Name "default" -EnableAutoProvision

Write-Host "Created user $UPN with password $Password"
# add sample alerts
# manual action in Defender for Cloud/Security Alerts only?
Write-Host "please remember to add your sample alerts in Defender for Cloud/SecurityAlerts/Sample Alerts"
