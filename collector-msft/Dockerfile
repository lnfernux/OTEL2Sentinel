FROM otel/opentelemetry-collector-contrib:0.153.0

# collector-config.yaml carries logs, traces and metrics. Metrics require an
# Azure Monitor workspace behind the DCR; build with
# COLLECTOR_CONFIG=collector-config-no-metrics.yaml when you do not have one.
ARG COLLECTOR_CONFIG=collector-config.yaml

COPY ${COLLECTOR_CONFIG} /etc/otelcol-contrib/config.yaml

EXPOSE 4318

ENTRYPOINT ["/otelcol-contrib"]
CMD ["--config=/etc/otelcol-contrib/config.yaml"]
