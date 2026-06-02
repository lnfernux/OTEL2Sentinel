param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true)]
    [string]$CollectorAppName,

    [Parameter(Mandatory = $false)]
    [int]$TailLines = 50
)

$ErrorActionPreference = 'Stop'

$collectorFqdn = az containerapp show --resource-group $ResourceGroupName --name $CollectorAppName --query properties.configuration.ingress.fqdn -o tsv

Write-Host "Collector public endpoint: https://$collectorFqdn"
Write-Host "Recent collector logs:"
az containerapp logs show --resource-group $ResourceGroupName --name $CollectorAppName --tail $TailLines
