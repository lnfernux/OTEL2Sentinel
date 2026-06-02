param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true)]
    [string]$Location,

    [Parameter(Mandatory = $true)]
    [string]$LogAnalyticsWorkspaceName,

    [Parameter(Mandatory = $true)]
    [string]$AppInsightsName
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

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

$workspaceId = az monitor log-analytics workspace show --resource-group $ResourceGroupName --workspace-name $LogAnalyticsWorkspaceName --query customerId -o tsv

$workspaceResourceId = az monitor log-analytics workspace show --resource-group $ResourceGroupName --workspace-name $LogAnalyticsWorkspaceName --query id -o tsv

$appInsightsExists = $null
try {
    $appInsightsExists = az resource show --resource-group $ResourceGroupName --resource-type "Microsoft.Insights/components" --name $AppInsightsName --query id -o tsv 2>$null
}
catch {
    $appInsightsExists = $null
}

if ([string]::IsNullOrWhiteSpace($appInsightsExists)) {
    $appInsightsResource = @{
        type = "Microsoft.Insights/components"
        apiVersion = "2020-02-02"
        name = $AppInsightsName
        location = $Location
        kind = "web"
        properties = @{
            Application_Type = "web"
            WorkspaceResourceId = $workspaceResourceId
        }
    } | ConvertTo-Json -Depth 6 -Compress

    $tmpJson = [System.IO.Path]::GetTempFileName()
    try {
        Set-Content -Path $tmpJson -Value $appInsightsResource -Encoding utf8
        az resource create --resource-group $ResourceGroupName --resource-type "Microsoft.Insights/components" --name $AppInsightsName --is-full-object --properties "@$tmpJson" | Out-Null
    }
    finally {
        Remove-Item -Path $tmpJson -Force -ErrorAction SilentlyContinue
    }

    Write-Host "Workspace-based Application Insights created: $AppInsightsName"
}
else {
    Write-Host "Workspace-based Application Insights already exists: $AppInsightsName"
}

$connectionString = az resource show --resource-group $ResourceGroupName --resource-type "Microsoft.Insights/components" --name $AppInsightsName --query properties.ConnectionString -o tsv

Write-Host "Log Analytics workspace ready: $LogAnalyticsWorkspaceName"
Write-Host "Workspace-based Application Insights ready: $AppInsightsName"
Write-Host "APPLICATIONINSIGHTS_CONNECTION_STRING=$connectionString"
