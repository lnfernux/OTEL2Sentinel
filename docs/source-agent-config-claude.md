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
