# Setup Guide

This guide covers deployment, source configuration, auth handling, and operations for the OTEL2Sentinel collector.

## Prerequisites

- Azure subscription with permission to create or update resource groups and monitoring resources.
- Azure CLI with `containerapp` extension.
- PowerShell 7+
- Docker not required locally (image build runs in ACR Tasks).

## Signal Modes

Default mode in this repository is logs-only.

- Logs-only:
  - Keep [collector/collector-config.yaml](collector/collector-config.yaml) with only the `logs` pipeline enabled.
  - Recommended for lower ingestion cost and simpler operations.
- Logs + metrics:
  - Add `metrics` pipeline in [collector/collector-config.yaml](collector/collector-config.yaml), rebuild, and redeploy.
- Logs + traces + metrics:
  - Add both `traces` and `metrics` pipelines, rebuild, and redeploy.

After changing collector pipelines, redeploy the app image.

## Auth Model

Current state: no server-side auth is enforced on the collector receiver.

- Client-side contract:
  - Sources are expected to send `OTEL_EXPORTER_OTLP_HEADERS=Authorization=Bearer <shared-secret>`.
- Runtime secret wiring:
  - Deployment stores the shared token as the `auth-header` Container App secret for future use.
- Why not enforced in the collector:
  - The `bearertokenauth` extension works and was tested. It is left disabled by default to keep the deploy script's smoke tests and any pre-existing source configurations frictionless. VS Code Copilot **can** send the bearer header via the `OTEL_EXPORTER_OTLP_HEADERS` environment variable (see [docs/source-agent-config-vscode.md](docs/source-agent-config-vscode.md) and the official [Monitor agent usage with OpenTelemetry](https://code.visualstudio.com/docs/copilot/guides/monitoring-agents) guide). To enforce collector-side, re-enable the `bearertokenauth` extension and ensure every source sets `OTEL_EXPORTER_OTLP_HEADERS`.
- Pass-2 enforcement path:
  - Place an authenticated edge in front of the collector (API Management, Front Door) and accept all traffic from the edge only.

## Deploy

Run from repository root:

```powershell
./infra/cli/deploy-all.ps1 -SubscriptionId "<subscription-guid>" -Location "westeurope" -ResourceGroupName "rg-otel2sentinel-dev" -LogAnalyticsWorkspaceName "law-otel2sentinel-dev" -AppInsightsName "appi-otel2sentinel-dev" -AcrName "acrotel2sentineldev" -ContainerAppsEnvironmentName "cae-otel2sentinel-dev" -CollectorAppName "ca-otel-collector-dev" -ImageTag "v1"
```

For future reference, you can add `-CollectorAuthHeaderValue "<shared-secret>"` for adding auth if you have APIM or FrontDoor checking headers.

## Configure Sources

- VS Code Copilot: [docs/source-agent-config-vscode.md](docs/source-agent-config-vscode.md)
- Claude Code: [docs/source-agent-config-claude.md](docs/source-agent-config-claude.md)
- Claude Cowork: [docs/source-agent-config-claude-cowork.md](docs/source-agent-config-claude-cowork.md)
- Office agents: [docs/source-agent-config-office-agents.md](docs/source-agent-config-office-agents.md)

## Verify

```powershell
./infra/cli/06-verify-telemetry.ps1 -ResourceGroupName "rg-otel2sentinel-dev" -CollectorAppName "ca-otel-collector-dev"
```

Optional smoke test:

```powershell
./infra/cli/07-send-synthetic-otlp.ps1 -CollectorBaseUrl "https://<collector-fqdn>" -AuthHeaderValue "<shared-secret>"
```

*Skip the `-AuthHeaderValue` if you deployed without it.* 

## Operations

1. Rotate the shared header value and update source agents.
2. Build and deploy a new collector image tag for config changes.
3. Monitor ingestion volume and retention in Log Analytics.

## Troubleshooting

- Collector app does not start:
  - Check `az containerapp logs show` output for collector startup errors.
  - Confirm `APPLICATIONINSIGHTS_CONNECTION_STRING` is present.
- No telemetry in App Insights:
  - Validate client endpoint and protocol (`http/protobuf` recommended).
  - Confirm sender includes expected OTLP auth header if configured.
  - Send synthetic traffic and inspect collector logs.
  - If using logs-only mode, metrics and traces are intentionally dropped.
- ACR image pull errors:
  - Verify ACR credentials and app registry settings.

## Microsoft-native OTLP variant (side-by-side)

The original collector exports to Application Insights via the `azuremonitor` exporter using a connection string. Microsoft's native OTLP ingestion path (announced 2026-06) instead has the collector POST OTLP directly to a Data Collection Endpoint backed by a Data Collection Rule, authenticated with Microsoft Entra via the [Azure Authentication extension](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/extension/azureauthextension). See the [Learn doc](https://learn.microsoft.com/azure/azure-monitor/containers/opentelemetry-protocol-ingestion).

This variant lives in [collector-msft/](collector-msft/) and [infra-msft/cli/](infra-msft/cli/). The original collector and infra are untouched.

### What's different

- Exporter: `otlp_http/azuremonitor` -> DCE (instead of `azuremonitor` -> App Insights connection string).
- Auth: Container App system-assigned managed identity with `Monitoring Metrics Publisher` on the DCR.
- No `APPLICATIONINSIGHTS_CONNECTION_STRING` secret on the Container App.
- Data lands in OTel-semantic streams (`Microsoft-OTLP-Logs` / `Microsoft-OTLP-Traces`) rather than `AppTraces` / `AppDependencies`. Existing KQL from the original path does not port 1:1.
- Collector pinned to 0.153.0 to cover the 0.148.0+ requirement for `managed_identity: {}`.
- Logs, traces, and metrics all follow the Azure Monitor OTLP path. If a source emits cumulative OTLP metrics, add `cumulativetodelta` as described in the Learn doc.

### Prerequisites you create first

The infra scripts assume the DCE + DCR already exist. Two supported ways:

1. **App Insights with OTLP support: On** (recommended). In the Azure portal, create a new Application Insights resource and toggle `OTLP support` to `On` on the Basics tab. After deployment, the Overview blade exposes the DCR resource ID and the logs, traces, and metrics OTLP endpoint URLs.
2. **Manual** via the ARM template in [AzureMonitorCommunity](https://github.com/microsoft/AzureMonitorCommunity/blob/master/Azure%20Services/Azure%20Monitor/OpenTelemetry/OTLP_DCE_DCR_ARM_Template.txt).

Capture: the DCR resource ID, the logs OTLP endpoint, the traces OTLP endpoint, and the metrics OTLP endpoint.

If you use the portal-generated App Insights path, copy those endpoint URLs exactly as shown in **OTLP Connection Info**. Do not reconstruct or normalize the stream names by hand.

### Deploy

```powershell
./infra-msft/cli/deploy-all-msft.ps1 `
  -SubscriptionId "<subscription-guid>" `
  -Location "westeurope" `
  -ResourceGroupName "rg-otel2sentinel-msft" `
  -LogAnalyticsWorkspaceName "law-otel2sentinel-msft" `
  -AcrName "acrotel2sentinelmsft" `
  -ContainerAppsEnvironmentName "cae-otel2sentinel-msft" `
  -CollectorAppName "ca-otel-collector-msft" `
  -DcrResourceId "/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Insights/dataCollectionRules/<dcr>" `
  -OtlpLogsEndpoint "<exact-logs-endpoint-url>" `
  -OtlpTracesEndpoint "<exact-traces-endpoint-url>" `
  -OtlpMetricsEndpoint "<exact-metrics-endpoint-url>" `
  -ImageTag "v1"
```

The orchestrator reuses the shared `infra/cli/01` (resource group), `03` (ACR), and `04` (Container Apps environment) scripts, then runs the Microsoft-variant `05` (deploy with SAMI), `06` (grant RBAC on the DCR), and `07` (verify).

### Source-side caveats unchanged

Source agents still POST to the Container App's public FQDN with no enforced auth on the receiver. The bearer-token gap from the original auth model still applies; address it with API Management, Front Door, or the `bearertokenauth` extension if needed.

