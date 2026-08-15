import type {
  Capsule,
  CapsuleErrorCode,
  CreateCapsuleRequest,
  RouteEstimate,
  TripDraft,
} from "@commute-capsule/domain";

// ponytail: simple constant, swap for real env config when a build pipeline needs it.
export const API_BASE_URL = "http://localhost:3000";

/**
 * Carries the API's stable `{ code, message }` error shape (see
 * apps/api/src/services/capsule-service.ts's CapsuleError) across the HTTP
 * boundary so screens can eventually branch on `code` instead of only
 * showing a generic message. `code` is undefined for responses that aren't
 * in that shape (e.g. INVALID_REQUEST, INTERNAL_ERROR).
 */
export class ApiError extends Error {
  constructor(
    readonly code: CapsuleErrorCode | undefined,
    message: string,
  ) {
    super(message);
    this.name = "ApiError";
  }
}

async function postJson<TResponse>(path: string, body: unknown): Promise<TResponse> {
  const response = await fetch(`${API_BASE_URL}${path}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });

  if (!response.ok) {
    const parsed: unknown = await response.json().catch(() => undefined);
    const code =
      parsed && typeof parsed === "object" && "code" in parsed
        ? ((parsed as { code: unknown }).code as CapsuleErrorCode)
        : undefined;
    const message =
      parsed && typeof parsed === "object" && "message" in parsed
        ? String((parsed as { message: unknown }).message)
        : `Request to ${path} failed with status ${response.status}`;
    throw new ApiError(code, message);
  }

  return (await response.json()) as TResponse;
}

export const apiClient = {
  estimateTrip: (draft: TripDraft): Promise<RouteEstimate> =>
    postJson<RouteEstimate>("/v1/trips/estimate", draft),
  createCapsule: (request: CreateCapsuleRequest): Promise<Capsule> =>
    postJson<Capsule>("/v1/capsules", request),
};
