import type { RouteEstimate, TripDraft } from "@commute-capsule/domain";
import type { RoutingProvider } from "../providers/routing";

export class TripService {
  constructor(private readonly routing: RoutingProvider) {}

  async estimate(input: TripDraft): Promise<RouteEstimate> {
    // A user-edited manual duration always wins, even if the routing
    // provider would succeed -- the manual override must never be
    // silently discarded (see TripCheckScreen's edit-and-continue flow).
    if (input.manualSeconds && input.manualSeconds >= 60) {
      return { durationSeconds: input.manualSeconds, summary: "Manual duration", source: "manual" };
    }
    const estimate = await this.routing.estimate(input);
    return { ...estimate, source: "routing" };
  }
}
