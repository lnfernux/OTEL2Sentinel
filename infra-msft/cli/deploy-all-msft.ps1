param(
    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $true)]
    [string]$Location,

    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true)]
    [string]$LogAnalyticsWorkspaceName,

    [Parameter(Mandatory = $true)]
    [string]$AcrName,

    [Parameter(Mandatory = $true)]
    [string]$ContainerAppsEnvironmentName,

    [Parameter(Mandatory = $true)]
    [string]$CollectorAppName,

    # Pre-created via the Azure portal (App Insights with "OTLP support: On")
    # or the AzureMonitorCommunity ARM template for DCE+DCR.
    # See: https://learn.microsoft.com/azure/azure-monitor/containers/opentelemetry-protocol-ingestion
    [Parameter(Mandatory = $true)]
    [string]$DcrResourceId,

    [Parameter(Mandatory = $true)]
    [string]$OtlpLogsEndpoint,

    [Parameter(Mandatory = $true)]
    [string]$OtlpTracesEndpoint,

    [Parameter(Mandatory = $true)]
    [string]$OtlpMetricsEndpoint,

    [Parameter(Mandatory = $false)]
    [string]$ImageTag = 'v1'
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

# Shared infrastructure steps from the original infra/cli tree.
$sharedInfra = Resolve-Path "$PSScriptRoot\..\..\infra\cli"

& "$sharedInfra\01-create-resource-group.ps1" -SubscriptionId $SubscriptionId -Location $Location -ResourceGroupName $ResourceGroupName

# Log Analytics workspace for Container App platform logs. Application
# telemetry goes via the DCR, not directly into this workspace.
$lawResourceId = $null
try {
    $lawResourceId = az monitor log-analytics workspace show --resource-group $ResourceGroupName --workspace-name $LogAnalyticsWorkspaceName --query id -o tsv 2>$null
}
catch {
    $lawResourceId = $null
}

if ([string]::IsNullOrWhiteSpace($lawResourceId)) {
    az monitor log-analytics workspace create --resource-group $ResourceGroupName --workspace-name $LogAnalyticsWorkspaceName --location $Location | Out-Null
    Write-Host "Log Analytics workspace created: $LogAnalyticsWorkspaceName"
}
else {
    Write-Host "Log Analytics workspace already exists: $LogAnalyticsWorkspaceName"
}

& "$sharedInfra\03-create-acr.ps1" -ResourceGroupName $ResourceGroupName -AcrName $AcrName

& "$sharedInfra\04-create-containerapps-env.ps1" -ResourceGroupName $ResourceGroupName -Location $Location -ContainerAppsEnvironmentName $ContainerAppsEnvironmentName -LogAnalyticsWorkspaceName $LogAnalyticsWorkspaceName

& "$PSScriptRoot\05-deploy-collector-app-mi.ps1" -ResourceGroupName $ResourceGroupName -AcrName $AcrName -ContainerAppsEnvironmentName $ContainerAppsEnvironmentName -CollectorAppName $CollectorAppName -OtlpLogsEndpoint $OtlpLogsEndpoint -OtlpTracesEndpoint $OtlpTracesEndpoint -OtlpMetricsEndpoint $OtlpMetricsEndpoint -ImageTag $ImageTag

& "$PSScriptRoot\06-grant-dcr-rbac.ps1" -ResourceGroupName $ResourceGroupName -CollectorAppName $CollectorAppName -DcrResourceId $DcrResourceId

& "$PSScriptRoot\07-verify-telemetry-otlp.ps1" -ResourceGroupName $ResourceGroupName -CollectorAppName $CollectorAppName -LogAnalyticsWorkspaceName $LogAnalyticsWorkspaceName
