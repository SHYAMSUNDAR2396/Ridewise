const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

/** Retry `fn` with bounded exponential backoff. Rethrows the final error. */
export async function withRetry<T>(
  fn: () => Promise<T>,
  attempts = 3,
  baseDelayMs = 200,
): Promise<T> {
  let lastError: unknown;

  for (let attempt = 0; attempt < attempts; attempt += 1) {
    try {
      return await fn();
    } catch (error) {
      lastError = error;
      if (attempt < attempts - 1) await sleep(baseDelayMs * 2 ** attempt);
    }
  }

  throw lastError;
}
