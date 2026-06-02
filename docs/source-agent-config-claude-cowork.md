# Claude Cowork Source Configuration

> **Note:** This document was generated with the help of AI and reconciled against the official Anthropic support article "Monitor Claude Cowork activity with OpenTelemetry" (see Sources). Cowork does **not** use the standard `OTEL_*` environment variables.

This document defines how to point Claude Cowork at the OTEL2Sentinel collector.

## How Cowork OTel export is configured

Cowork OTel is configured per organization through the Claude Desktop UI by an organization admin:

1. Open **Claude Desktop**.
2. Navigate to **Organization settings → Cowork**.
3. Enter the **OTLP endpoint** — your collector URL (for OTEL2Sentinel: `https://<collector-fqdn>`).
4. Select the **OTLP protocol**: `HTTP/JSON` or `HTTP/protobuf`. gRPC is not supported.
5. Add **OTLP headers** required for authentication, for example:
   `Authorization=Bearer <shared-secret>`
6. Save.

Events begin flowing immediately. Anthropic encrypts the auth headers at rest.

## Requirements

- Claude **Team** or **Enterprise** plan.
- Claude Desktop **1.1.4173 or later**.
- An admin account with access to Organization settings.

## Baseline values for OTEL2Sentinel

| Field | Value |
| --- | --- |
| OTLP endpoint | `https://<collector-fqdn>` (your Container App FQDN from `05-deploy-collector-app.ps1`) |
| OTLP protocol | `HTTP/protobuf` (matches the collector's OTLP/HTTP receiver on `:4318`) |
| OTLP headers | `Authorization=Bearer <shared-secret>` — the value you supplied as `-CollectorAuthHeaderValue` at deploy time |

`HTTP/JSON` also works against the same collector receiver if you prefer.

## What gets exported

Cowork streams structured events for:

- User prompts (full prompt text).
- Tool and MCP invocations (server name, tool name, parameters, success/failure, duration).
- File access (paths read or modified, including via MCPs and folder-scoped local files).
- Skills and plugins invoked.
- Human approval decisions (approve / reject / auto).
- API requests and errors (model, token counts, estimated cost, duration, errors).

A shared `prompt.id` attribute ties all events triggered by one user prompt together.

## Privacy and content considerations

These are upstream defaults, not collector-side toggles. If any of them conflict with your retention policy, filter or redact in the collector before forwarding downstream:

- **User prompt content is included by default.** There is no Cowork-side flag to disable it.
- **Tool parameter values** (file paths, command arguments, etc.) are exported in the `tool_parameters` field and may contain sensitive data.
- **User email addresses** are present in event attributes.
- No data flows until an admin configures an OTLP endpoint.

## Signal mode notes

- Cowork emits **events** (OTel logs/events signal). The default collector pipeline in [collector/collector-config.yaml](../collector/collector-config.yaml) already exports logs to Application Insights, so no collector changes are needed for Cowork.
- The `agent.surface` / `agent.vendor` style attributes are unique to Office agents and do not appear on Cowork events.

## Sources

Verified against the official Anthropic support article:

- **Monitor Claude Cowork activity with OpenTelemetry** — covers the Claude Desktop UI configuration (endpoint, protocol, headers), event categories, requirements, and privacy defaults: <https://support.claude.com/en/articles/14477985-monitor-claude-cowork-activity-with-opentelemetry>
- Cowork monitoring event schema reference (linked from the support article): <https://claude.com/docs/cowork/monitoring#events>
- OTLP/HTTP endpoint shape (`/v1/logs`, `/v1/traces`, `/v1/metrics`): <https://opentelemetry.io/docs/specs/otlp/#otlphttp>

Key facts confirmed by the upstream article:

- Cowork is configured **only** through Claude Desktop's Organization settings UI. There is no `OTEL_EXPORTER_OTLP_*` environment variable path for Cowork.
- Only HTTP-based OTLP (`HTTP/JSON` or `HTTP/protobuf`) is supported. gRPC is not an option.
- Auth headers configured in the UI are encrypted at rest on Anthropic servers.
- When a custom OTLP endpoint is configured, events flow there; Cowork is not visible in the Anthropic Compliance API today, but each event carries a shared user account identifier you can use to correlate against Compliance API data.
