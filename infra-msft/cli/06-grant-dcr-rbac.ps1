param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true)]
    [string]$CollectorAppName,

    # Full ARM resource ID of the Data Collection Rule, e.g.
    # /subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Insights/dataCollectionRules/<dcr>
    [Parameter(Mandatory = $true)]
    [string]$DcrResourceId
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

$principalId = az containerapp show --resource-group $ResourceGroupName --name $CollectorAppName --query identity.principalId -o tsv

if ([string]::IsNullOrWhiteSpace($principalId)) {
    throw "Container App '$CollectorAppName' has no system-assigned identity. Run 05-deploy-collector-app-mi.ps1 first."
}

$existing = az role assignment list --assignee $principalId --scope $DcrResourceId --role "Monitoring Metrics Publisher" --query "[0].id" -o tsv 2>$null

if ([string]::IsNullOrWhiteSpace($existing)) {
    az role assignment create --assignee-object-id $principalId --assignee-principal-type ServicePrincipal --role "Monitoring Metrics Publisher" --scope $DcrResourceId | Out-Null
    Write-Host "Granted 'Monitoring Metrics Publisher' on $DcrResourceId to $principalId"
}
else {
    Write-Host "Role assignment already exists for $principalId on $DcrResourceId"
}
