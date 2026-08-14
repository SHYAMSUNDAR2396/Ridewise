import type { RouteEstimate, TripDraft } from "@commute-capsule/domain";
import type { RoutingProvider } from "../providers/routing";

export class TripService {
  constructor(private readonly routing: RoutingProvider) {}

  async estimate(input: TripDraft): Promise<RouteEstimate> {
    try {
      const estimate = await this.routing.estimate(input);
      return { ...estimate, source: "routing" };
    } catch (error) {
      if (input.manualSeconds && input.manualSeconds >= 60) {
        return { durationSeconds: input.manualSeconds, summary: "Manual duration", source: "manual" };
      }
      throw error;
    }
  }
}
