param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true)]
    [string]$CollectorAppName,

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

Write-Host "Recent collector console logs (looking for OTLP exporter activity):"
az containerapp logs show --resource-group $ResourceGroupName --name $CollectorAppName --tail 100 --type console

Write-Host ""
if (-not [string]::IsNullOrWhiteSpace($LogAnalyticsWorkspaceName)) {
    Write-Host "Recent Log Analytics tables (last $LookbackMinutes minutes):"
    $workspaceId = az monitor log-analytics workspace show --resource-group $ResourceGroupName --workspace-name $LogAnalyticsWorkspaceName --query customerId -o tsv
    $recentTables = Invoke-LogAnalyticsQuery -WorkspaceId $workspaceId -Query "search * | where TimeGenerated > ago(${LookbackMinutes}m) | summarize Count=count() by `$table | top 10 by Count desc"

    if ($recentTables.tables.Count -gt 0 -and $recentTables.tables[0].rows.Count -gt 0) {
        foreach ($row in $recentTables.tables[0].rows) {
            Write-Host ("  {0}: {1}" -f $row[0], $row[1])
        }
    }
    else {
        Write-Host "  No rows found in the selected lookback window."
    }

    Write-Host ""
    if (-not [string]::IsNullOrWhiteSpace($SearchText)) {
        $escapedSearchText = $SearchText.Replace('\', '\\').Replace('"', '\"')
        $searchQuery = "search `"$escapedSearchText`" | where TimeGenerated > ago(${LookbackMinutes}m) | take 20"
        $searchResults = Invoke-LogAnalyticsQuery -WorkspaceId $workspaceId -Query $searchQuery

        if ($searchResults.tables.Count -gt 0 -and $searchResults.tables[0].rows.Count -gt 0) {
            Write-Host "Found rows matching the supplied search text:"
            $searchResults.tables[0].rows | ConvertTo-Json -Depth 8
        }
        else {
            Write-Host "No rows matched the supplied search text in the last $LookbackMinutes minutes."
            Write-Host "Content capture primarily shows up on span/event attributes, so exact-text matches depend on the table schema and ingestion latency."
        }

        Write-Host ""
    }
}

Write-Host "Telemetry destination: OTel semantic tables in Log Analytics. Sample KQL:"
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
Write-Host "If you used Application Insights 'OTLP support: On', the App Insights"
Write-Host "agents view and end-to-end transaction view should also be populated."
