import { create } from "zustand";

type NowPlayingState = {
  capsuleId: string | null;
  setCapsuleId: (capsuleId: string | null) => void;
};

export const useNowPlaying = create<NowPlayingState>((set) => ({
  capsuleId: null,
  setCapsuleId: (capsuleId) => set({ capsuleId }),
}));
