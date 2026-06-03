param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true)]
    [string]$AcrName,

    [Parameter(Mandatory = $true)]
    [string]$ContainerAppsEnvironmentName,

    [Parameter(Mandatory = $true)]
    [string]$CollectorAppName,

    # OTLP endpoint URLs from the Application Insights "OTLP Connection Info"
    # blade, or manually constructed from the DCE + DCR immutable ID.
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

$acrLoginServer = az acr show --resource-group $ResourceGroupName --name $AcrName --query loginServer -o tsv
$imageName = "$acrLoginServer/otel-collector-msft:$ImageTag"

$envProvisioningState = az containerapp env show --name $ContainerAppsEnvironmentName --resource-group $ResourceGroupName --query properties.provisioningState -o tsv
if ($envProvisioningState -ne 'Succeeded') {
    throw "Managed environment '$ContainerAppsEnvironmentName' is '$envProvisioningState'. Collector app deployment requires a Succeeded environment."
}

Push-Location "$PSScriptRoot\..\..\collector-msft"
try {
    az acr build --registry $AcrName --image "otel-collector-msft:$ImageTag" . | Out-Null
}
finally {
    Pop-Location
}

$acrUser = az acr credential show -n $AcrName --query username -o tsv
$acrPassword = az acr credential show -n $AcrName --query "passwords[0].value" -o tsv

$envVars = @(
    "OTLP_LOGS_ENDPOINT=$OtlpLogsEndpoint",
    "OTLP_TRACES_ENDPOINT=$OtlpTracesEndpoint",
    "OTLP_METRICS_ENDPOINT=$OtlpMetricsEndpoint"
)

$collectorExists = $null
try {
    $collectorExists = az containerapp show --resource-group $ResourceGroupName --name $CollectorAppName --query id -o tsv 2>$null
}
catch {
    $collectorExists = $null
}

if ([string]::IsNullOrWhiteSpace($collectorExists)) {
    az containerapp create --name $CollectorAppName --resource-group $ResourceGroupName --environment $ContainerAppsEnvironmentName --image $imageName --ingress external --target-port 4318 --min-replicas 1 --max-replicas 1 --registry-server $acrLoginServer --registry-username $acrUser --registry-password $acrPassword --cpu 0.5 --memory 1.0Gi --system-assigned --env-vars $envVars | Out-Null

    Write-Host "Collector app created with system-assigned identity: $CollectorAppName"
}
else {
    az containerapp identity assign --resource-group $ResourceGroupName --name $CollectorAppName --system-assigned | Out-Null

    az containerapp update --name $CollectorAppName --resource-group $ResourceGroupName --image $imageName --set-env-vars $envVars --min-replicas 1 --max-replicas 1 | Out-Null

    Write-Host "Collector app updated: $CollectorAppName"
}

$principalId = az containerapp show --resource-group $ResourceGroupName --name $CollectorAppName --query identity.principalId -o tsv
$collectorUrl = az containerapp show --resource-group $ResourceGroupName --name $CollectorAppName --query properties.configuration.ingress.fqdn -o tsv

Write-Host "Collector app deployed: $CollectorAppName"
Write-Host "Collector endpoint: https://$collectorUrl"
Write-Host "System-assigned principalId: $principalId"
Write-Host "Next: grant 'Monitoring Metrics Publisher' on the DCR to this principal (see 06-grant-dcr-rbac.ps1)."
