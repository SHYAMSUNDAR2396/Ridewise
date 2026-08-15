import type { TransportMode, TripDraft } from "@commute-capsule/domain";

export interface RoutingEstimate {
  durationSeconds: number;
  summary: string;
}

export interface RoutingProvider {
  estimate(input: TripDraft): Promise<RoutingEstimate>;
}

const drivingLikeModes: Partial<Record<TransportMode, "DRIVE" | "BICYCLE" | "WALK">> = {
  car: "DRIVE",
  bike: "BICYCLE",
  walk: "WALK",
};

const transitModes: TransportMode[] = ["metro", "bus", "local_train"];

function toGoogleTravelMode(mode: TransportMode): "DRIVE" | "BICYCLE" | "WALK" | "TRANSIT" {
  if (transitModes.includes(mode)) return "TRANSIT";
  return drivingLikeModes[mode] ?? "DRIVE";
}

const GOOGLE_ROUTES_ENDPOINT = "https://routes.googleapis.com/directions/v2:computeRoutes";

export class GoogleRoutingProvider implements RoutingProvider {
  constructor(private readonly apiKey: string) {}

  async estimate(input: TripDraft): Promise<RoutingEstimate> {
    const travelMode = toGoogleTravelMode(input.transportMode);
    const response = await fetch(GOOGLE_ROUTES_ENDPOINT, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-Goog-Api-Key": this.apiKey,
        "X-Goog-FieldMask": "routes.duration,routes.description",
      },
      body: JSON.stringify({
        origin: { address: input.startLabel },
        destination: { address: input.endLabel },
        travelMode,
      }),
    });

    if (!response.ok) {
      throw new Error("Google Routes request failed");
    }

    const data = (await response.json()) as {
      routes?: Array<{ duration?: string; description?: string }>;
    };
    const route = data.routes?.[0];
    if (!route?.duration) {
      throw new Error("Google Routes returned no usable route");
    }

    const durationSeconds = Number.parseInt(route.duration.replace(/s$/, ""), 10);
    if (!Number.isFinite(durationSeconds)) {
      throw new Error("Google Routes returned an unparseable duration");
    }

    return {
      durationSeconds,
      summary: route.description ?? `${input.transportMode} via ${input.startLabel} to ${input.endLabel}`,
    };
  }
}
