import AsyncStorage from "@react-native-async-storage/async-storage";
import { create } from "zustand";
import { createJSONStorage, persist } from "zustand/middleware";
import type { Capsule } from "@commute-capsule/domain";

/**
 * A capsule as kept in the local library: the generated Capsule plus
 * per-device state (listening progress, saved flag, and offline copies of
 * each segment). Segments are ordered, so downloads are tracked per segment
 * index rather than as a single audio URI.
 */
export type StoredCapsule = Capsule & {
  progressSeconds: number;
  saved: boolean;
  downloadedSegmentUris: Record<number, string>;
};

/** A capsule is offline-playable only once every segment has a local file. */
export function isFullyDownloaded(capsule: StoredCapsule): boolean {
  return Object.keys(capsule.downloadedSegmentUris).length === capsule.segments.length;
}

type LibraryState = {
  capsules: StoredCapsule[];
  upsert: (capsule: Capsule) => void;
  setProgress: (id: string, progressSeconds: number) => void;
  toggleSaved: (id: string) => void;
  markSegmentDownloaded: (id: string, segmentIndex: number, uri: string) => void;
  remove: (id: string) => void;
};

export const useCapsuleStore = create<LibraryState>()(
  persist(
    (set) => ({
      capsules: [],
      upsert: (capsule) =>
        set((state) => {
          const existing = state.capsules.find((item) => item.id === capsule.id);
          const stored: StoredCapsule = {
            ...capsule,
            progressSeconds: existing?.progressSeconds ?? 0,
            saved: existing?.saved ?? false,
            downloadedSegmentUris: existing?.downloadedSegmentUris ?? {},
          };
          return {
            capsules: [stored, ...state.capsules.filter((item) => item.id !== capsule.id)],
          };
        }),
      setProgress: (id, progressSeconds) =>
        set((state) => ({
          capsules: state.capsules.map((item) =>
            item.id === id ? { ...item, progressSeconds } : item,
          ),
        })),
      toggleSaved: (id) =>
        set((state) => ({
          capsules: state.capsules.map((item) =>
            item.id === id ? { ...item, saved: !item.saved } : item,
          ),
        })),
      markSegmentDownloaded: (id, segmentIndex, uri) =>
        set((state) => ({
          capsules: state.capsules.map((item) =>
            item.id === id
              ? {
                  ...item,
                  downloadedSegmentUris: { ...item.downloadedSegmentUris, [segmentIndex]: uri },
                }
              : item,
          ),
        })),
      remove: (id) =>
        set((state) => ({
          capsules: state.capsules.filter((item) => item.id !== id),
        })),
    }),
    { name: "capsule-library", storage: createJSONStorage(() => AsyncStorage) },
  ),
);
