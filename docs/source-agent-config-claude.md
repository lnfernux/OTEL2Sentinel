# Claude Code Source Configuration

> **Note:** This document was generated with the help of AI. The variable names below were cross-checked against the official Claude Code Monitoring docs at <https://code.claude.com/docs/en/monitoring-usage>, but verify against the current upstream docs before deploying — flag names like `CLAUDE_CODE_ENHANCED_TELEMETRY_BETA` and the `OTEL_LOG_*` privacy gates may evolve. `CLAUDE_CODE_ENHANCED_TELEMETRY_BETA` only takes effect when traces are exported; it is a no-op in logs-only mode.

This document defines minimal Claude Code configuration for OTEL2Sentinel.

## Baseline Configuration

Environment variables:

- `CLAUDE_CODE_ENABLE_TELEMETRY=1`
- `OTEL_METRICS_EXPORTER=none`
- `OTEL_LOGS_EXPORTER=otlp`
- `OTEL_TRACES_EXPORTER=none`
- `CLAUDE_CODE_ENHANCED_TELEMETRY_BETA=1`
- `OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf`
- `OTEL_EXPORTER_OTLP_ENDPOINT=https://<collector-fqdn>`
- `OTEL_EXPORTER_OTLP_HEADERS=Authorization=Bearer <shared-secret>`

Privacy defaults:

- `OTEL_LOG_USER_PROMPTS=0`
- `OTEL_LOG_TOOL_DETAILS=0`
- `OTEL_LOG_TOOL_CONTENT=0`
- `OTEL_LOG_RAW_API_BODIES=0`

Optional settings file example: [env/settings.claude.sample.json](../env/settings.claude.sample.json)

## Signal Modes

### Logs-only mode (default in this repo)

- Collector: only `logs` pipeline is enabled in [collector/collector-config.yaml](../collector/collector-config.yaml).
- Claude: keep `OTEL_METRICS_EXPORTER=none` and `OTEL_TRACES_EXPORTER=none`.

### Logs + metrics mode

- Collector: add `metrics` pipeline in [collector/collector-config.yaml](../collector/collector-config.yaml).
- Claude: set `OTEL_METRICS_EXPORTER=otlp`.

### Logs + traces + metrics mode

- Collector: add both `traces` and `metrics` pipelines in [collector/collector-config.yaml](../collector/collector-config.yaml).
- Claude: set `OTEL_METRICS_EXPORTER=otlp` and `OTEL_TRACES_EXPORTER=otlp`.

## Scenarios

### Local test collector

- Endpoint: `http://localhost:4318`
- Protocol: `http/protobuf`
- Header: optional

### Azure collector endpoint

- Endpoint: `https://<collector-fqdn>`
- Protocol: `http/protobuf`
- Header: required

### Debug mode

- Temporarily enable additional telemetry flags.
- Revert to privacy defaults after debugging.

## Measured behaviour

Measured 2026-08-17 from one headless `claude -p` session against the Microsoft-native path, Claude Code 2.1.197, privacy defaults applied. 43 records reached `OTelLogs`. The session invoked no tools, so tool events are absent from the table rather than unsupported.

Resource attributes on every record: `service.name=claude-code`, `service.version`, `host.arch`, `os.type`, `os.version`, plus whatever the collector's `resource` processor upserts.

| `claude_code.*` event | Records |
| --- | --- |
| `plugin_loaded` | 19 |
| `hook_registered` | 12 |
| `mcp_server_connection` | 3 |
| `hook_execution_start` | 3 |
| `hook_execution_complete` | 3 |
| `user_prompt` | 1 |
| `assistant_response` | 1 |
| `api_request` | 1 |

Startup registration dominates the volume, so a short session is mostly plugin and hook records rather than conversation. Sizing an ingestion budget from turn count alone therefore undercounts.

`api_request` carries `model`, `input_tokens`, `output_tokens`, `cache_read_tokens`, `cache_creation_tokens`, `cost_usd`, `cost_usd_micros`, `duration_ms` and `request_id`. It is the record to bill and rate-limit from.

### Identity attributes

Every record carries `user.email`, `user.id`, `user.account_uuid`, `user.account_id`, `organization.id` and `session.id`, regardless of the `OTEL_LOG_*` settings. A shared `prompt.id` ties all records from one turn together.

With all four gates at `0`, `prompt` and `response` are emitted with the literal value `<REDACTED>`, while `prompt_length` and `response_length` are still exported. Treat the gates as content suppression, not as de-identification.

### Events added by the gates

Setting all four to `1` does more than unredact existing fields. Four event types appear that are absent entirely at the defaults:

| Event | Content |
| --- | --- |
| `api_request_body` | Raw request body sent to the API |
| `api_response_body` | Raw response body |
| `tool_decision` | `tool_parameters`, including the executed shell command verbatim |
| `tool_result` | Tool output, including file contents |

Account for the volume before enabling it. `api_response_body` is normally the largest event by size, and `tool_decision` records any credential that appeared on a command line.

## Sources

Verified against the official Anthropic Claude Code monitoring documentation:

- Monitoring overview, quick start, and full environment-variable reference (covers `CLAUDE_CODE_ENABLE_TELEMETRY`, `OTEL_METRICS_EXPORTER`, `OTEL_LOGS_EXPORTER`, `OTEL_TRACES_EXPORTER`, `OTEL_EXPORTER_OTLP_PROTOCOL`, `OTEL_EXPORTER_OTLP_ENDPOINT`, `OTEL_EXPORTER_OTLP_HEADERS`, `OTEL_LOG_USER_PROMPTS`, `OTEL_LOG_TOOL_DETAILS`, `OTEL_LOG_TOOL_CONTENT`, `OTEL_LOG_RAW_API_BODIES`, and `CLAUDE_CODE_ENHANCED_TELEMETRY_BETA`): <https://code.claude.com/docs/en/monitoring-usage>
- Managed settings file (`.claude/settings.json` `env` block precedence used by [../env/settings.claude.sample.json](../env/settings.claude.sample.json)): <https://code.claude.com/docs/en/settings>
- OpenTelemetry SDK environment variable spec (general `OTEL_*` semantics): <https://opentelemetry.io/docs/specs/otel/configuration/sdk-environment-variables/>
- OTLP exporter configuration spec: <https://opentelemetry.io/docs/specs/otel/protocol/exporter/>

Caveats from the upstream doc that affect this repo:

- `CLAUDE_CODE_ENHANCED_TELEMETRY_BETA=1` only enables the **traces** beta. In logs-only mode it is a no-op; safe to leave set, but not required.
- Claude Code does **not** propagate `OTEL_*` env vars to subprocesses (Bash tool, hooks, MCP servers). Re-set them inside any subprocess that should export its own telemetry.
- Default export interval is 60 s for metrics and 5 s for logs.
