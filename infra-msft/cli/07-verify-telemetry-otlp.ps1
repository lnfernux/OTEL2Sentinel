param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true)]
    [string]$CollectorAppName,

    # Full ARM resource ID of the Data Collection Rule. The destination
    # workspace is resolved from it, because OTel telemetry lands in the DCR's
    # destination and not in the workspace that backs Container App console logs.
    [Parameter(Mandatory = $false)]
    [string]$DcrResourceId,

    # Workspace backing Container App console logs. Platform data only.
    [Parameter(Mandatory = $false)]
    [string]$LogAnalyticsWorkspaceName,

    [Parameter(Mandatory = $false)]
    [string]$SearchText,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 1440)]
    [int]$LookbackMinutes = 30
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

function Invoke-LogAnalyticsQuery {
    param(
        [Parameter(Mandatory = $true)]
        [string]$WorkspaceId,

        [Parameter(Mandatory = $true)]
        [string]$Query
    )

    $requestFile = Join-Path $env:TEMP ("loganalytics-query-{0}.json" -f ([guid]::NewGuid().ToString('N')))
    $requestBody = @{ query = $Query } | ConvertTo-Json -Compress

    try {
        Set-Content -Path $requestFile -Value $requestBody -NoNewline
        az rest --method post --url "https://api.loganalytics.io/v1/workspaces/$WorkspaceId/query" --resource "https://api.loganalytics.io" --headers "Content-Type=application/json" --body "@$requestFile" | ConvertFrom-Json
    }
    finally {
        Remove-Item -Path $requestFile -Force -ErrorAction SilentlyContinue
    }
}

function Write-QueryRows {
    param($Result, [string]$Label)

    if ($Result.tables.Count -gt 0 -and $Result.tables[0].rows.Count -gt 0) {
        Write-Host "  $Label"
        foreach ($row in $Result.tables[0].rows) {
            Write-Host ("    " + ($row -join '  |  '))
        }
    }
    else {
        Write-Host "  $Label none"
    }
}

Write-Host "Recent collector console logs (looking for OTLP exporter activity):"
az containerapp logs show --resource-group $ResourceGroupName --name $CollectorAppName --tail 100 --type console
Write-Host ""

if (-not [string]::IsNullOrWhiteSpace($DcrResourceId)) {
    # az monitor data-collection rule show pins an older API version and returns
    # an empty destinations block, so query ARM directly at 2024-03-11.
    $destinationWorkspaceId = az rest --method get --url "https://management.azure.com/$DcrResourceId`?api-version=2024-03-11" --query "properties.destinations.logAnalytics[0].workspaceResourceId" -o tsv

    if ([string]::IsNullOrWhiteSpace($destinationWorkspaceId)) {
        Write-Host "DCR '$DcrResourceId' declares no Log Analytics destination. Nothing to query."
    }
    else {
        $destinationName = az monitor log-analytics workspace show --ids $destinationWorkspaceId --query name -o tsv
        $destinationCustomerId = az monitor log-analytics workspace show --ids $destinationWorkspaceId --query customerId -o tsv

        Write-Host "Telemetry destination workspace: $destinationName (last $LookbackMinutes minutes)"

        foreach ($table in @('OTelLogs', 'OTelSpans', 'OTelEvents', 'OTelResources')) {
            $counts = Invoke-LogAnalyticsQuery -WorkspaceId $destinationCustomerId -Query "$table | where TimeGenerated > ago(${LookbackMinutes}m) | summarize Rows=count()"
            Write-QueryRows -Result $counts -Label "${table}:"
        }

        Write-Host ""
        $byService = Invoke-LogAnalyticsQuery -WorkspaceId $destinationCustomerId -Query "union isfuzzy=true OTelLogs, OTelSpans, OTelEvents | where TimeGenerated > ago(${LookbackMinutes}m) | summarize Rows=count() by Type, ServiceName | order by Rows desc | take 20"
        Write-QueryRows -Result $byService -Label "Rows by table and ServiceName:"
        Write-Host ""

        if (-not [string]::IsNullOrWhiteSpace($SearchText)) {
            $escapedSearchText = $SearchText.Replace('\', '\\').Replace('"', '\"')
            $searchResults = Invoke-LogAnalyticsQuery -WorkspaceId $destinationCustomerId -Query "search `"$escapedSearchText`" | where TimeGenerated > ago(${LookbackMinutes}m) | take 20"

            if ($searchResults.tables.Count -gt 0 -and $searchResults.tables[0].rows.Count -gt 0) {
                Write-Host "Rows matching the supplied search text:"
                $searchResults.tables[0].rows | ConvertTo-Json -Depth 8
            }
            else {
                Write-Host "No rows matched the supplied search text in the last $LookbackMinutes minutes."
                Write-Host "Content capture primarily shows up on span/event attributes, so exact-text matches depend on the table schema and ingestion latency."
            }

            Write-Host ""
        }
    }
}
else {
    Write-Host "No -DcrResourceId supplied, so the telemetry destination was not queried."
    Write-Host ""
}

if (-not [string]::IsNullOrWhiteSpace($LogAnalyticsWorkspaceName)) {
    Write-Host "Container App platform logs in $LogAnalyticsWorkspaceName (last $LookbackMinutes minutes):"
    $platformCustomerId = az monitor log-analytics workspace show --resource-group $ResourceGroupName --workspace-name $LogAnalyticsWorkspaceName --query customerId -o tsv
    $platformTables = Invoke-LogAnalyticsQuery -WorkspaceId $platformCustomerId -Query "search * | where TimeGenerated > ago(${LookbackMinutes}m) | summarize Count=count() by `$table | top 10 by Count desc"
    Write-QueryRows -Result $platformTables -Label "Tables:"
    Write-Host ""
    Write-Host "  This workspace holds ContainerAppConsoleLogs_CL and friends."
    Write-Host "  Agent telemetry does not land here; it follows the DCR."
    Write-Host ""
}

Write-Host "Sample KQL against the telemetry destination workspace:"
Write-Host ""
Write-Host "  // Logs ingested via Microsoft-OTLP-Logs"
Write-Host "  OTelLogs | take 50"
Write-Host ""
Write-Host "  // Spans ingested via Microsoft-OTLP-Traces"
Write-Host "  OTelSpans | take 50"
Write-Host ""
Write-Host "  // Events derived from span events"
Write-Host "  OTelEvents | take 50"
Write-Host ""
Write-Host "First ingestion into a new OTel table can take 5-15 minutes to become queryable."
Write-Host "If you used Application Insights 'OTLP support: On', the App Insights"
Write-Host "agents view and end-to-end transaction view should also be populated."
