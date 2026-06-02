FROM otel/opentelemetry-collector-contrib:0.153.0

COPY collector-config.yaml /etc/otelcol-contrib/config.yaml

EXPOSE 4317 4318

ENTRYPOINT ["/otelcol-contrib"]
CMD ["--config=/etc/otelcol-contrib/config.yaml"]
