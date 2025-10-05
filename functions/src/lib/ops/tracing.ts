import { Resource } from '@opentelemetry/resources';
import { SemanticResourceAttributes } from '@opentelemetry/semantic-conventions';
import { NodeTracerProvider } from '@opentelemetry/sdk-trace-node';
import { BatchSpanProcessor } from '@opentelemetry/sdk-trace-base';
// If you export traces, add an exporter here, e.g. OTLP/Google Trace:
// import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-http';

let _initialized = false;

/** Initialize OpenTelemetry tracing once (no‑op in local dev). */
export function initTracing(): void {
  if (_initialized) return;

  try {
    const provider = new NodeTracerProvider({
      resource: new Resource({
        [SemanticResourceAttributes.SERVICE_NAME]: 'functions',
      }),
    });

    // If you configure an exporter, add it here:
    // const exporter = new OTLPTraceExporter();
    // provider.addSpanProcessor(new BatchSpanProcessor(exporter));
    provider.addSpanProcessor(new BatchSpanProcessor({} as any)); // no-op

    provider.register();
    _initialized = true;
  } catch {
    // Tracing is optional; swallow errors in serverless envs
    _initialized = true;
  }
}
