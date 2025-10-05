export interface SpanLike {
  setAttribute: (_k: string, _v: unknown) => void;
  recordException: (_e: unknown) => void;
  end: () => void;
}

const noopSpan: SpanLike = {
  setAttribute: () => {},
  recordException: () => {},
  end: () => {},
};

export function initializeTracer(): void {
  // Optional real tracer init (OTel), or keep as no-op for cold-start savings
}

export function startChildSpan(): SpanLike {
  // If you wire real OTel later, return real span here; keep fallback:
  return noopSpan;
}

export function withSpan<T>(fn: () => Promise<T>): Promise<T> {
  const span = startChildSpan();
  return fn()
    .catch((e) => {
      span.recordException(e);
      throw e;
    })
    .finally(() => span.end());
}

export function getCurrentSpan(): SpanLike { return noopSpan; }
export function setSpanAttribute(): void {}
export function recordSpanException(): void {}

