
export type SpanLike = {
  setAttribute: (k: string, v: unknown) => void;
  recordException: (e: unknown) => void;
  end: () => void;
};

const noopSpan: SpanLike = {
  setAttribute: () => {},
  recordException: () => {},
  end: () => {},
};

export function initializeTracer(_serviceName = 'functions'): void {
  // Optional real tracer init (OTel), or keep as no-op for cold-start savings
}

export function startChildSpan(_name: string): SpanLike {
  // If you wire real OTel later, return real span here; keep fallback:
  return noopSpan;
}

export function withSpan<T>(name: string, fn: () => Promise<T>): Promise<T> {
  const span = startChildSpan(name);
  return fn()
    .catch((e) => {
      span.recordException(e);
      throw e;
    })
    .finally(() => span.end());
}

export function getCurrentSpan(): SpanLike { return noopSpan; }
export function setSpanAttribute(_k: string, _v: unknown): void {}
export function recordSpanException(_e: unknown): void {}

