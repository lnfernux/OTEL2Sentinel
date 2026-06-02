# VS Code Copilot Source Configuration

> **Note:** This document was generated with the help of AI and then reconciled against the official "Monitor agent usage with OpenTelemetry" guide (see Sources). Copilot's OTel surface evolves; spot-check the upstream page before relying on it.

This document defines minimal VS Code Copilot client configuration for OTEL2Sentinel.

## Configuration Precedence

1. Environment variables (take precedence over VS Code settings)
2. VS Code settings (`github.copilot.chat.otel.*`)

OTel activates when **any** of the following is true: `github.copilot.chat.otel.enabled=true`, `github.copilot.chat.otel.dbSpanExporter.enabled=true`, `COPILOT_OTEL_ENABLED=true`, or `OTEL_EXPORTER_OTLP_ENDPOINT` is set.

## Baseline Configuration

Environment variables:

- `COPILOT_OTEL_ENABLED=true` (optional; setting `OTEL_EXPORTER_OTLP_ENDPOINT` also activates OTel)
- `OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf` (only `grpc` changes behavior)
- `OTEL_EXPORTER_OTLP_ENDPOINT=https://<collector-fqdn>`
- `OTEL_EXPORTER_OTLP_HEADERS=Authorization=Bearer <shared-secret>` — **the only supported way to send auth headers**; there is no settings-file equivalent.
- `COPILOT_OTEL_CAPTURE_CONTENT=false`

Optional settings file example: [env/settings.vscode.sample.json](../env/settings.vscode.sample.json)

## Signal Mode Notes

- Copilot Chat emits traces, metrics, and events — there is no per-signal on/off toggle on the source side.
- This repository runs logs-only by default in [collector/collector-config.yaml](../collector/collector-config.yaml); non-log signals from Copilot are dropped at the collector when the corresponding pipeline is not enabled.

## Content capture (`captureContent`)

The `github.copilot.chat.otel.captureContent` setting (env equivalent `COPILOT_OTEL_CAPTURE_CONTENT`) controls whether full prompt/response content is included in span attributes. It is **off by default** and this repo keeps it off.

When disabled, only metadata is emitted: model names, token counts, durations, tool names, success/error status, and the other non-content attributes from the GenAI semantic conventions. No prompts, responses, system prompts, tool schemas, tool arguments, or tool results are sent.

When enabled, the following span attributes are populated (see the upstream guide for the full list):

- `gen_ai.input.messages` — full prompt messages
- `gen_ai.output.messages` — full response messages
- `gen_ai.tool.definitions` — tool schemas
- `gen_ai.tool.call.arguments` — tool input arguments
- `gen_ai.tool.call.result` — tool output
- `github.copilot.tool.parameters.command` — shell tool commands (truncated)
- `github.copilot.tool.parameters.file_path` — file paths for file tools
- `github.copilot.tool.parameters.mcp_server_name` — MCP server names

This can include source code, file contents, secrets pasted into prompts, and tool output. Only enable it in trusted environments and pair it with `github.copilot.chat.otel.maxAttributeSizeChars` (default `0` = no truncation) to bound per-attribute size against your backend's limits.

Reference: <https://code.visualstudio.com/docs/copilot/guides/monitoring-agents#_content-capture>

## Scenarios

### Local test collector

- Endpoint: `http://localhost:4318`
- Protocol: `http/protobuf`
- Header: optional

### Azure collector endpoint

- Endpoint: `https://<collector-fqdn>`
- Protocol: `http/protobuf`
- Header: required

### Strict privacy mode

- Keep content capture disabled.
- Export logs only (collector default).

## Sources

Verified against the official VS Code "Monitor agent usage with OpenTelemetry" guide:

- Full env-var and settings reference (confirms `COPILOT_OTEL_ENABLED`, `COPILOT_OTEL_ENDPOINT`, `COPILOT_OTEL_PROTOCOL`, `COPILOT_OTEL_CAPTURE_CONTENT`, `COPILOT_OTEL_MAX_ATTRIBUTE_SIZE_CHARS`, `COPILOT_OTEL_LOG_LEVEL`, `COPILOT_OTEL_FILE_EXPORTER_PATH`, `COPILOT_OTEL_HTTP_INSTRUMENTATION`, plus the `github.copilot.chat.otel.*` settings and `maxAttributeSizeChars`): <https://code.visualstudio.com/docs/copilot/guides/monitoring-agents>
- VS Code Copilot settings reference (Observability section): <https://code.visualstudio.com/docs/copilot/reference/copilot-settings#_observability-settings>
- OpenTelemetry SDK environment variable spec: <https://opentelemetry.io/docs/specs/otel/configuration/sdk-environment-variables/>
- OTLP exporter configuration spec: <https://opentelemetry.io/docs/specs/otel/protocol/exporter/>
- OTLP/HTTP endpoint shape (`/v1/logs`, `/v1/traces`, `/v1/metrics`): <https://opentelemetry.io/docs/specs/otlp/#otlphttp>

Key behaviors confirmed by the guide that affect this repo:

- Environment variables always take precedence over VS Code settings.
- Authentication headers for remote collectors are **only** configurable via `OTEL_EXPORTER_OTLP_HEADERS`. There is no settings-file field for headers.
- Terminal CLI sessions started with *New Copilot CLI Session* run in a separate process; the extension forwards `COPILOT_OTEL_ENABLED` and `OTEL_EXPORTER_OTLP_ENDPOINT` to the terminal. The CLI runtime only supports `otlp-http` even when `otlp-grpc` is configured.
- Content capture is off by default; enabling it can include code, file contents, and user prompts. Treat the auth header in [env/example.vscode.env](../env/example.vscode.env) as sensitive.
