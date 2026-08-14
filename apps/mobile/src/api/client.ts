import type {
  Capsule,
  CreateCapsuleRequest,
  RouteEstimate,
  TripDraft,
} from "@commute-capsule/domain";

// ponytail: simple constant, swap for real env config when a build pipeline needs it.
export const API_BASE_URL = "http://localhost:3000";

async function postJson<TResponse>(path: string, body: unknown): Promise<TResponse> {
  const response = await fetch(`${API_BASE_URL}${path}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });

  if (!response.ok) {
    throw new Error(`Request to ${path} failed with status ${response.status}`);
  }

  return (await response.json()) as TResponse;
}

export const apiClient = {
  estimateTrip: (draft: TripDraft): Promise<RouteEstimate> =>
    postJson<RouteEstimate>("/v1/trips/estimate", draft),
  createCapsule: (request: CreateCapsuleRequest): Promise<Capsule> =>
    postJson<Capsule>("/v1/capsules", request),
};
