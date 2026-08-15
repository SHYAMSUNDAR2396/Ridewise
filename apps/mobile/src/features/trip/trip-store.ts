import { create } from "zustand";
import type { TransportMode, TripDraft } from "@commute-capsule/domain";

type TripState = {
  draft: Partial<TripDraft>;
  setEndpoints: (startLabel: string, endLabel: string) => void;
  setTransportMode: (transportMode: TransportMode) => void;
  setManualSeconds: (manualSeconds?: number) => void;
  setEstimatedSeconds: (estimatedSeconds?: number) => void;
};

export const useTripStore = create<TripState>((set) => ({
  draft: {},
  setEndpoints: (startLabel, endLabel) =>
    set((state) => {
      const draft = { ...state.draft, startLabel, endLabel };
      delete draft.manualSeconds;
      return { draft };
    }),
  setTransportMode: (transportMode) =>
    set((state) => {
      const draft = { ...state.draft, transportMode };
      delete draft.manualSeconds;
      return { draft };
    }),
  setManualSeconds: (manualSeconds) =>
    set((state) => ({ draft: { ...state.draft, manualSeconds } })),
  setEstimatedSeconds: (estimatedSeconds) =>
    set((state) => ({ draft: { ...state.draft, estimatedSeconds } })),
}));
