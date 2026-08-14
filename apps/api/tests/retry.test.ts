import { describe, it, expect, vi } from "vitest";
import { withRetry } from "../src/services/retry";

describe("withRetry", () => {
  it("returns the first successful result without retrying", async () => {
    const fn = vi.fn().mockResolvedValue("ok");
    await expect(withRetry(fn, 3, 1)).resolves.toBe("ok");
    expect(fn).toHaveBeenCalledTimes(1);
  });

  it("retries until it succeeds", async () => {
    const fn = vi
      .fn()
      .mockRejectedValueOnce(new Error("429"))
      .mockResolvedValue("ok");
    await expect(withRetry(fn, 3, 1)).resolves.toBe("ok");
    expect(fn).toHaveBeenCalledTimes(2);
  });

  it("rethrows the last error once attempts are exhausted", async () => {
    const fn = vi.fn().mockRejectedValue(new Error("503"));
    await expect(withRetry(fn, 3, 1)).rejects.toThrow("503");
    expect(fn).toHaveBeenCalledTimes(3);
  });
});
