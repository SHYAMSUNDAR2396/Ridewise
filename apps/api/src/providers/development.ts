import type { TripDraft } from "@commute-capsule/domain";
import type { RoutingEstimate, RoutingProvider } from "./routing";

const FIXED_DURATION_SECONDS = 18 * 60;

// ponytail: no network in development mode — a fixed 18 minute estimate is
// enough to exercise every downstream consumer deterministically.
export class DevelopmentRoutingProvider implements RoutingProvider {
  async estimate(input: TripDraft): Promise<RoutingEstimate> {
    return {
      durationSeconds: FIXED_DURATION_SECONDS,
      summary: `${input.transportMode} from ${input.startLabel} to ${input.endLabel}`,
    };
  }
}
