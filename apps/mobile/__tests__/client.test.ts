import { ApiError, apiClient } from "../src/api/client";

describe("apiClient error handling", () => {
  afterEach(() => {
    (global.fetch as jest.Mock | undefined)?.mockRestore?.();
  });

  it("throws an ApiError carrying the response's code and message on a mapped failure", async () => {
    global.fetch = jest.fn().mockResolvedValue({
      ok: false,
      status: 502,
      json: async () => ({ code: "ROUTE_UNAVAILABLE", message: "We couldn't estimate this route." }),
    });

    await expect(
      apiClient.estimateTrip({ startLabel: "Andheri", endLabel: "Bandra", transportMode: "metro" }),
    ).rejects.toMatchObject({
      code: "ROUTE_UNAVAILABLE",
      message: "We couldn't estimate this route.",
    });
  });

  it("throws an ApiError instance", async () => {
    global.fetch = jest.fn().mockResolvedValue({
      ok: false,
      status: 502,
      json: async () => ({ code: "ROUTE_UNAVAILABLE", message: "We couldn't estimate this route." }),
    });

    await expect(
      apiClient.estimateTrip({ startLabel: "Andheri", endLabel: "Bandra", transportMode: "metro" }),
    ).rejects.toBeInstanceOf(ApiError);
  });
});
