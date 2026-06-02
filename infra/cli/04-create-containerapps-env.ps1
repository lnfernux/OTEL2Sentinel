param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true)]
    [string]$Location,

    [Parameter(Mandatory = $true)]
    [string]$ContainerAppsEnvironmentName,

    [Parameter(Mandatory = $true)]
    [string]$LogAnalyticsWorkspaceName
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

$workspaceId = az monitor log-analytics workspace show --resource-group $ResourceGroupName --workspace-name $LogAnalyticsWorkspaceName --query customerId -o tsv

$workspaceKey = az monitor log-analytics workspace get-shared-keys --resource-group $ResourceGroupName --workspace-name $LogAnalyticsWorkspaceName --query primarySharedKey -o tsv

$envExists = $null
try {
    $envExists = az containerapp env show --name $ContainerAppsEnvironmentName --resource-group $ResourceGroupName --query id -o tsv 2>$null
}
catch {
    $envExists = $null
}

if ([string]::IsNullOrWhiteSpace($envExists)) {
    Write-Host "Container Apps environment not found. Creating: $ContainerAppsEnvironmentName"
    az containerapp env create --name $ContainerAppsEnvironmentName --resource-group $ResourceGroupName --location $Location --logs-workspace-id $workspaceId --logs-workspace-key $workspaceKey | Out-Null

    Write-Host "Container Apps environment created: $ContainerAppsEnvironmentName"
}
else {
    Write-Host "Container Apps environment already exists: $ContainerAppsEnvironmentName"
}

$envProvisioningState = az containerapp env show --name $ContainerAppsEnvironmentName --resource-group $ResourceGroupName --query properties.provisioningState -o tsv
if ($envProvisioningState -ne 'Succeeded') {
    throw "Container Apps environment '$ContainerAppsEnvironmentName' is in provisioning state '$envProvisioningState'. Deployment cannot continue until it is Succeeded. If this environment is stuck/failed, create a new environment name in a region with available capacity and rerun deployment."
}

Write-Host "Container Apps environment ready: $ContainerAppsEnvironmentName"
