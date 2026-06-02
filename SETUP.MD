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
