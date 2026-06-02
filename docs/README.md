# docs

Configuration guides for connecting coding agents to the OTEL2Sentinel collector.

## Table of Contents

- [Quick start](#quick-start)
- [Supported tools](#supported-tools)

---

## Quick start

Every agent needs the same three OTLP environment variables pointing at your deployed collector.

| Variable | Value |
|---|---|
| `OTEL_EXPORTER_OTLP_PROTOCOL` | `http/protobuf` |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | `https://<collector-fqdn>` — printed at the end of `infra/cli/05-deploy-collector-app.ps1` |
| `OTEL_EXPORTER_OTLP_HEADERS` | `Authorization=Bearer <shared-secret>` — the value you passed as `-CollectorAuthHeaderValue` at deploy time |

For a local test collector substitute `http://localhost:4318` for the endpoint and omit the header.

### Signal mode

Default is logs-only. Override per-agent as documented in each guide.

| Variable | Logs-only (default) | Logs + metrics | Full |
|---|---|---|---|
| `OTEL_LOGS_EXPORTER` | `otlp` | `otlp` | `otlp` |
| `OTEL_METRICS_EXPORTER` | `none` | `otlp` | `otlp` |
| `OTEL_TRACES_EXPORTER` | `none` | `none` | `otlp` |

---

## Supported tools

| Tool | Key tool-specific vars | Env template | Settings template | Guide | Tested |
|---|---|---|---|---|---|
| **VS Code Copilot** | `COPILOT_OTEL_ENABLED=true`<br>`COPILOT_OTEL_CAPTURE_CONTENT=false` | [env/example.vscode.env](../env/example.vscode.env) | [env/settings.vscode.sample.json](../env/settings.vscode.sample.json) | [source-agent-config-vscode.md](source-agent-config-vscode.md) | Tested on VSCode 1.122.1 x64|
| **Claude Code** | `CLAUDE_CODE_ENABLE_TELEMETRY=1`<br>`CLAUDE_CODE_ENHANCED_TELEMETRY_BETA=1`<br>`OTEL_LOG_USER_PROMPTS=0` | [env/example.claude.env](../env/example.claude.env) | [env/settings.claude.sample.json](../env/settings.claude.sample.json) | [source-agent-config-claude.md](source-agent-config-claude.md) |No|
| **Claude Cowork** | Standard OTel vars only | — | — | [source-agent-config-claude-cowork.md](source-agent-config-claude-cowork.md) |No|
| **Office Agents** | Standard OTel vars or host policy | — | — | [source-agent-config-office-agents.md](source-agent-config-office-agents.md) |No|

## Known issues

### Claude OTEL

There are multiple known issues for Claude OTEL forwarding:

- https://github.com/anthropics/claude-code/issues/35105
- https://github.com/anthropics/claude-code/issues/39471
- https://github.com/anthropics/claude-code/issues/64396

Several of the issues are either due to centralized configuration overriding the admin console, such as MDM solutions like Intune pushing configuration files that take precedence over the UI. If everything appears correctly configured but no logs are appearing, check any configuration from MDMs. There are also reports of version to version regression on OTEL output.
