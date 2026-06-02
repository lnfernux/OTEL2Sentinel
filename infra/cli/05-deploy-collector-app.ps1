param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true)]
    [string]$AcrName,

    [Parameter(Mandatory = $true)]
    [string]$ContainerAppsEnvironmentName,

    [Parameter(Mandatory = $true)]
    [string]$CollectorAppName,

    [Parameter(Mandatory = $true)]
    [string]$AppInsightsConnectionString,

    [Parameter(Mandatory = $true)]
    [string]$CollectorAuthHeaderValue,

    [Parameter(Mandatory = $false)]
    [string]$ImageTag = 'v1'
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

$acrLoginServer = az acr show --resource-group $ResourceGroupName --name $AcrName --query loginServer -o tsv
$imageName = "$acrLoginServer/otel-collector:$ImageTag"

$envProvisioningState = az containerapp env show --name $ContainerAppsEnvironmentName --resource-group $ResourceGroupName --query properties.provisioningState -o tsv
if ($envProvisioningState -ne 'Succeeded') {
    throw "Managed environment '$ContainerAppsEnvironmentName' is '$envProvisioningState'. Collector app deployment requires a Succeeded environment."
}

Push-Location "$PSScriptRoot\..\..\collector"
try {
    az acr build --registry $AcrName --image "otel-collector:$ImageTag" . | Out-Null
}
finally {
    Pop-Location
}

$acrUser = az acr credential show -n $AcrName --query username -o tsv
$acrPassword = az acr credential show -n $AcrName --query "passwords[0].value" -o tsv

$collectorExists = $null
try {
    $collectorExists = az containerapp show --resource-group $ResourceGroupName --name $CollectorAppName --query id -o tsv 2>$null
}
catch {
    $collectorExists = $null
}

if ([string]::IsNullOrWhiteSpace($collectorExists)) {
    az containerapp create --name $CollectorAppName --resource-group $ResourceGroupName --environment $ContainerAppsEnvironmentName --image $imageName --ingress external --target-port 4318 --min-replicas 1 --max-replicas 1 --registry-server $acrLoginServer --registry-username $acrUser --registry-password $acrPassword --cpu 0.5 --memory 1.0Gi --secrets appinsights-conn="$AppInsightsConnectionString" auth-header="$CollectorAuthHeaderValue" --env-vars APPLICATIONINSIGHTS_CONNECTION_STRING=secretref:appinsights-conn REQUIRED_OTEL_AUTH_HEADER=secretref:auth-header | Out-Null

    Write-Host "Collector app created: $CollectorAppName"
}
else {
    az containerapp secret set --resource-group $ResourceGroupName --name $CollectorAppName --secrets appinsights-conn="$AppInsightsConnectionString" auth-header="$CollectorAuthHeaderValue" | Out-Null

    az containerapp update --name $CollectorAppName --resource-group $ResourceGroupName --image $imageName --set-env-vars APPLICATIONINSIGHTS_CONNECTION_STRING=secretref:appinsights-conn REQUIRED_OTEL_AUTH_HEADER=secretref:auth-header --min-replicas 1 --max-replicas 1 | Out-Null

    Write-Host "Collector app updated: $CollectorAppName"
}

$collectorUrl = az containerapp show --resource-group $ResourceGroupName --name $CollectorAppName --query properties.configuration.ingress.fqdn -o tsv

Write-Host "Collector app deployed: $CollectorAppName"
Write-Host "Collector endpoint: https://$collectorUrl"
Write-Host "OTLP HTTP endpoint: https://$collectorUrl/v1/traces (and /v1/logs, /v1/metrics)"
