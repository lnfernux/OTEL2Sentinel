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
    [string]$AppInsightsName,

    [Parameter(Mandatory = $true)]
    [string]$AcrName,

    [Parameter(Mandatory = $true)]
    [string]$ContainerAppsEnvironmentName,

    [Parameter(Mandatory = $true)]
    [string]$CollectorAppName,

    [Parameter(Mandatory = $true)]
    [string]$CollectorAuthHeaderValue,

    [Parameter(Mandatory = $false)]
    [string]$ImageTag = 'v1'
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

& "$PSScriptRoot\01-create-resource-group.ps1" -SubscriptionId $SubscriptionId -Location $Location -ResourceGroupName $ResourceGroupName

& "$PSScriptRoot\02-create-monitoring.ps1" -ResourceGroupName $ResourceGroupName -Location $Location -LogAnalyticsWorkspaceName $LogAnalyticsWorkspaceName -AppInsightsName $AppInsightsName

& "$PSScriptRoot\03-create-acr.ps1" -ResourceGroupName $ResourceGroupName -AcrName $AcrName

& "$PSScriptRoot\04-create-containerapps-env.ps1" -ResourceGroupName $ResourceGroupName -Location $Location -ContainerAppsEnvironmentName $ContainerAppsEnvironmentName -LogAnalyticsWorkspaceName $LogAnalyticsWorkspaceName

$appInsightsConnectionString = az resource show --resource-group $ResourceGroupName --resource-type "Microsoft.Insights/components" --name $AppInsightsName --query properties.ConnectionString -o tsv

& "$PSScriptRoot\05-deploy-collector-app.ps1" -ResourceGroupName $ResourceGroupName -AcrName $AcrName -ContainerAppsEnvironmentName $ContainerAppsEnvironmentName -CollectorAppName $CollectorAppName -AppInsightsConnectionString $appInsightsConnectionString -CollectorAuthHeaderValue $CollectorAuthHeaderValue -ImageTag $ImageTag

& "$PSScriptRoot\06-verify-telemetry.ps1" -ResourceGroupName $ResourceGroupName -CollectorAppName $CollectorAppName
