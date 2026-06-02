param(
    [Parameter(Mandatory = $true)]
    [string]$CollectorBaseUrl,

    [Parameter(Mandatory = $false)]
    [string]$AuthHeaderValue = "",

    [Parameter(Mandatory = $false)]
    [string]$ServiceName = "otel2sentinel-smoke-test"
)

$ErrorActionPreference = 'Stop'

$headers = @{}
if (-not [string]::IsNullOrWhiteSpace($AuthHeaderValue)) {
    $headers["Authorization"] = "Bearer $AuthHeaderValue"
}

$epochNano = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() * 1000000
$traceId = "70f5f6154b1d4ac6b55f5dc7974b7188"
$spanId = "b9c7c989f97918e1"

$logPayload = @{
    resourceLogs = @(
        @{
            resource = @{
                attributes = @(
                    @{ key = "service.name"; value = @{ stringValue = $ServiceName } },
                    @{ key = "deployment.environment"; value = @{ stringValue = "dev" } }
                )
            }
            scopeLogs = @(
                @{
                    scope = @{ name = "smoke-test"; version = "1.0.0" }
                    logRecords = @(
                        @{
                            timeUnixNano = "$epochNano"
                            severityNumber = 9
                            severityText = "INFO"
                            body = @{ stringValue = "OTEL2Sentinel synthetic log" }
                            traceId = $traceId
                            spanId = $spanId
                        }
                    )
                }
            )
        }
    )
} | ConvertTo-Json -Depth 10

$logsUrl = "$CollectorBaseUrl/v1/logs"

Invoke-RestMethod -Method Post -Uri $logsUrl -Headers $headers -ContentType "application/json" -Body $logPayload | Out-Null

Write-Host "Synthetic log payload sent successfully."
Write-Host "Logs endpoint: $logsUrl"
