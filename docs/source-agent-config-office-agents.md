# Office Agents Source Configuration

> **Note:** This document was generated with the help of AI and reconciled against the official Anthropic support article "Configure a custom OpenTelemetry collector for Office agents" (see Sources). "Office agents" here means Anthropic's Claude add-in for Microsoft Office (Excel, Word, PowerPoint, Outlook). It does **not** mean Microsoft 365 Copilot — that has a different telemetry surface and is out of scope for this file.

This document defines how to point Anthropic's Office agents at the OTEL2Sentinel collector.

## How Office agent OTel export is configured

Office agents are add-ins that runs inside an Office WebView and is configured per organization through two channels depending on how you authenticate to Claude.

The two config keys, regardless of channel, are always:

| Key | Format | Description |
| --- | --- | --- |
| `otlp_endpoint` | HTTPS URL | Base URL of your OTLP collector. The add-in **strips any trailing slash and appends `/v1/traces`**, so set the base URL only. |
| `otlp_headers` | `key1=value1,key2=value2` | Authentication headers. Same format as the OpenTelemetry `OTEL_EXPORTER_OTLP_HEADERS` env var. |

Protocol is **OTLP/HTTP only**. gRPC is rejected at configuration time.

### Claude Enterprise (OAuth) organizations

An organization administrator sets the collector endpoint in the Claude.ai admin console:

1. Sign in to <https://claude.ai/admin-settings/office-agents>.
2. Set **`otlp_endpoint`** to `https://<collector-fqdn>` (no trailing `/v1/traces` — the add-in appends it).
3. Set **`otlp_headers`** to `Authorization=Bearer <shared-secret>`.
4. Save. The setting applies organization-wide.

### Direct provider deployments (Amazon Bedrock, Google Vertex AI, gateway)

For deployments that authenticate against your own model provider rather than Claude.ai, the same two keys are supplied through one of three channels. Anthropic recommends the [`claude-in-office` plugin](https://github.com/anthropics/financial-services-plugins/tree/main/claude-in-office) to wire these up; the manual channels are below for reference.

Precedence when multiple channels set a value: **bootstrap response > Entra claim > manifest URL parameter** (later wins).

1. **Manifest URL parameters** — append the keys as query string parameters to the taskpane URL in your custom add-in manifest:

   ```text
   https://<addin-host>/taskpane.html?otlp_endpoint=https://<collector-fqdn>&otlp_headers=Authorization=Bearer%20<token>
   ```

   URL-encode the values. Applies to every user who installs the manifest.

2. **Azure Entra ID directory extension** — register the keys as Entra directory extension attributes and assign them per user via Microsoft Graph. The add-in reads them from the user's ID token using Nested App Authentication. Requires `entra_sso=1` in the manifest URL parameters.

   | Claim | Maps to |
   | --- | --- |
   | `extn.otlp_endpoint` | `otlp_endpoint` |
   | `extn.otlp_headers` | `otlp_headers` |

3. **Bootstrap endpoint response** — a JSON endpoint your org hosts that the add-in calls at startup. Return:

   ```json
   {
     "otlp_endpoint": "https://<collector-fqdn>",
     "otlp_headers": "Authorization=Bearer <token>"
   }
   ```

   The bootstrap URL itself is set via `bootstrap_url` in the manifest URL parameters or an Entra `extn.bootstrap_url` claim. If an Entra ID token was acquired, it is passed to the bootstrap endpoint as a Bearer header so you can authenticate the user before returning per-user configuration.

> **Note:** These configuration channels apply to **Microsoft Office** deployments only. Google Workspace add-ins are configured separately.

## Baseline values for OTEL2Sentinel

| Field | Value |
| --- | --- |
| `otlp_endpoint` | `https://<collector-fqdn>` (the Container App FQDN from `05-deploy-collector-app.ps1`) — **no `/v1/traces` suffix** |
| `otlp_headers` | `Authorization=Bearer <shared-secret>` — the value you supplied as `-CollectorAuthHeaderValue` at deploy time |

## What gets exported

The add-in sends a tree of **spans** per user turn over OTLP/HTTP to `{otlp_endpoint}/v1/traces`:

- `agent.query` (root) — one per user turn. Carries `agent.surface` (`sheet`/`doc`/`slide`/`mail`), `agent.vendor=m`, `session.id`, `document.url`, prompt text (first 4000 chars), and on Claude.ai deployments `user.email`, `user.account_uuid`, `organization.id`, MCP/file-upload counts.
- `agent.stream` — one per API call to Claude (`model`, token counts, `stop_reason`, `request_id`).
- `agent.tool_execution` — one per tool call (`tool_name`, inputs, outputs, `tool.accept_decision`, surface-specific attrs like `sheet.cells_read`).
- `agent.compaction` — one per auto-summarization.
- `file.upload` — one per file upload (Claude.ai deployments only).

Resource attributes on every span: `service.name=office-agent`, `service.version=1.0.0`, `git.sha=<build>`.

## Important caveats

- **Metrics are not sent to custom collectors.** The `office_agent.*` counter namespace routes to Anthropic only. Every counter increment is also recorded as a span event on the active span, so the equivalent data is available in your traces.
- **When a custom endpoint is configured, telemetry goes exclusively to your collector.** Spans are **not** dual-sent to Anthropic. Losing collector visibility means losing the audit trail.
- **OTLP/HTTP only.** gRPC is rejected at configuration time because the add-in runs in an Office WebView.
- **No content redaction.** Your collector receives all span attributes, including prompt text, tool inputs and outputs, document URLs, and filenames. Assistant response text is the one exception — it is not included in span data.
- **Direct provider deployments have no Claude.ai identity** — spans carry only `session.id` and `document.url`. Correlate against your IdP / gateway / bootstrap logs to attribute activity to a user.
- The collector pipeline in [collector/collector-config.yaml](../collector/collector-config.yaml) must have the **`traces`** pipeline enabled for Office agent data (the default config in this repo is logs-only — see [SETUP.MD](../SETUP.MD) for enabling traces).

## Sources

Verified against the official Anthropic support article:

- **Configure a custom OpenTelemetry collector for Office agents** — full configuration channels, span schema, surface labels, and deployment-mode differences: <https://support.claude.com/en/articles/14447276-configure-a-custom-opentelemetry-collector-for-office-agents>
- `claude-in-office` Claude Code plugin (recommended setup path for direct provider deployments): <https://github.com/anthropics/financial-services-plugins/tree/main/claude-in-office>
- OTLP/HTTP endpoint shape: <https://opentelemetry.io/docs/specs/otlp/#otlphttp>

Out-of-scope references kept for reviewers who may confuse this with Microsoft 365 Copilot:

- Microsoft 365 Copilot is a separate product with its own telemetry/audit surface (Purview, M365 admin), governed by tenant policy rather than OTLP env vars. See <https://learn.microsoft.com/copilot/microsoft-365/microsoft-365-copilot-privacy> and <https://learn.microsoft.com/purview/audit-copilot>. This document does **not** cover M365 Copilot.
