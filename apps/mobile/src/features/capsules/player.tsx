import React, { useCallback, useEffect, useMemo, useRef } from "react";
import { AppState, Pressable, StyleSheet, Text, View } from "react-native";
import TrackPlayer, {
  State,
  useActiveTrack,
  usePlaybackState,
  useProgress,
} from "react-native-track-player";
import type { Capsule } from "@commute-capsule/domain";
import { segmentAt } from "./use-segment-queue";
import { playbackQueueUris } from "./download";
import { useCapsuleStore } from "./capsule-store";

export type CapsulePlayerProps = {
  capsule: Capsule;
  initialPositionSeconds: number;
  onProgress: (seconds: number) => void;
  /** Called when the native player reports a playback error (AUDIO_UNAVAILABLE). */
  onPlaybackError?: () => void;
};

const PROGRESS_REPORT_INTERVAL_SECONDS = 10;

function formatTime(totalSeconds: number): string {
  const seconds = Math.max(0, Math.round(totalSeconds));
  const minutes = Math.floor(seconds / 60);
  const remainder = seconds % 60;
  return `${minutes}:${remainder.toString().padStart(2, "0")}`;
}

/**
 * Queues a capsule's ordered segments into react-native-track-player and
 * renders playback controls. Once TrackPlayer.setQueue is called, the native
 * player advances between segments on its own -- there is no manual
 * "segment ended, load next" handling here.
 *
 * No playback-speed control and no regenerate action: both are out of scope
 * for this MVP.
 */
export function CapsulePlayer({
  capsule,
  initialPositionSeconds,
  onProgress,
  onPlaybackError,
}: CapsulePlayerProps): React.JSX.Element {
  const activeTrack = useActiveTrack();
  const progress = useProgress(1000);
  const playbackState = usePlaybackState();
  const isPlaying = playbackState.state === State.Playing;

  // Surface a native playback error (e.g. a segment URL that's gone stale
  // or unreachable) as AUDIO_UNAVAILABLE so the screen can offer retry.
  useEffect(() => {
    if (playbackState.state === State.Error) onPlaybackError?.();
  }, [playbackState.state, onPlaybackError]);

  const lastReportedRef = useRef(0);
  const wasPlayingRef = useRef(false);
  const elapsedSecondsRef = useRef(initialPositionSeconds);

  const currentSegmentIndex =
    typeof activeTrack?.segmentIndex === "number" ? activeTrack.segmentIndex : 0;

  const elapsedSeconds = useMemo(() => {
    const completed = capsule.segments
      .filter((segment) => segment.index < currentSegmentIndex)
      .reduce((sum, segment) => sum + segment.durationSeconds, 0);
    return completed + progress.position;
  }, [capsule.segments, currentSegmentIndex, progress.position]);

  const remainingSeconds = Math.max(0, capsule.audioSeconds - elapsedSeconds);

  // Build the queue once per capsule and resume from persisted progress.
  useEffect(() => {
    let cancelled = false;

    async function setup(): Promise<void> {
      const stored = useCapsuleStore.getState().capsules.find((item) => item.id === capsule.id);
      const uris = stored
        ? playbackQueueUris(stored)
        : capsule.segments.map((segment) => segment.url);

      await TrackPlayer.setQueue(
        capsule.segments.map((segment, position) => ({
          id: String(segment.index),
          url: uris[position],
          title: capsule.title,
          segmentIndex: segment.index,
        })),
      );
      if (cancelled) return;

      if (initialPositionSeconds > 0) {
        const { index, offsetSeconds } = segmentAt(capsule.segments, initialPositionSeconds);
        await TrackPlayer.skip(index);
        if (cancelled) return;
        await TrackPlayer.seekTo(offsetSeconds);
      }
    }

    setup();
    return () => {
      cancelled = true;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps -- queue is (re)built only when the capsule changes
  }, [capsule.id]);

  // Keep refs current so the unmount-flush cleanup below (a closure formed
  // once, at mount) can read the latest elapsed time and callback.
  const onProgressRef = useRef(onProgress);
  useEffect(() => {
    // Don't let a transient 0 (useProgress hasn't polled yet, e.g. while
    // setQueue/skip/seekTo are still resolving) clobber the real resume
    // position seeded into the ref -- only overwrite once we have genuine
    // nonzero progress to report.
    if (elapsedSeconds > 0) elapsedSecondsRef.current = elapsedSeconds;
    onProgressRef.current = onProgress;
  }, [elapsedSeconds, onProgress]);

  // Persist progress at least every 10 seconds.
  useEffect(() => {
    if (elapsedSeconds - lastReportedRef.current >= PROGRESS_REPORT_INTERVAL_SECONDS) {
      lastReportedRef.current = elapsedSeconds;
      onProgress(elapsedSeconds);
    }
  }, [elapsedSeconds, onProgress]);

  // Flush the latest known progress on unmount -- e.g. the user navigates
  // away mid-playback, which is the normal exit path, not an edge case.
  // Progress is otherwise only persisted on the 10s interval, on pause, and
  // on app backgrounding.
  useEffect(() => {
    return () => {
      if (elapsedSecondsRef.current === 0) return;
      onProgressRef.current(elapsedSecondsRef.current);
    };
  }, []);

  // Persist progress on pause.
  useEffect(() => {
    if (wasPlayingRef.current && !isPlaying) {
      lastReportedRef.current = elapsedSeconds;
      onProgress(elapsedSeconds);
    }
    wasPlayingRef.current = isPlaying;
  }, [isPlaying, elapsedSeconds, onProgress]);

  // Persist progress when the app backgrounds.
  useEffect(() => {
    const subscription = AppState.addEventListener("change", (nextState) => {
      if (nextState === "background") {
        lastReportedRef.current = elapsedSeconds;
        onProgress(elapsedSeconds);
      }
    });
    return () => subscription.remove();
  }, [elapsedSeconds, onProgress]);

  const togglePlayback = useCallback(() => {
    if (isPlaying) {
      TrackPlayer.pause();
    } else {
      TrackPlayer.play();
    }
  }, [isPlaying]);

  const skipBack = useCallback(() => {
    TrackPlayer.seekBy(-10);
  }, []);

  const skipForward = useCallback(() => {
    TrackPlayer.seekBy(30);
  }, []);

  const progressRatio =
    capsule.audioSeconds > 0 ? Math.min(1, elapsedSeconds / capsule.audioSeconds) : 0;

  return (
    <View style={styles.container}>
      <View style={styles.scrubberTrack}>
        <View style={[styles.scrubberFill, { width: `${progressRatio * 100}%` }]} />
      </View>
      <View style={styles.timestamps}>
        <Text style={styles.timestampText}>{formatTime(elapsedSeconds)}</Text>
        <Text style={styles.timestampText}>-{formatTime(remainingSeconds)}</Text>
      </View>

      <View style={styles.controls}>
        <Pressable
          accessibilityRole="button"
          accessibilityLabel="Replay 10 seconds"
          onPress={skipBack}
          style={styles.skipButton}
        >
          <Text style={styles.skipText}>-10s</Text>
        </Pressable>
        <Pressable
          accessibilityRole="button"
          accessibilityLabel={isPlaying ? "Pause" : "Play"}
          onPress={togglePlayback}
          style={styles.playButton}
        >
          <Text style={styles.playIcon}>{isPlaying ? "❚❚" : "▶"}</Text>
        </Pressable>
        <Pressable
          accessibilityRole="button"
          accessibilityLabel="Forward 30 seconds"
          onPress={skipForward}
          style={styles.skipButton}
        >
          <Text style={styles.skipText}>+30s</Text>
        </Pressable>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    width: "100%",
    paddingHorizontal: 24,
    gap: 8,
  },
  scrubberTrack: {
    height: 3,
    borderRadius: 2,
    backgroundColor: "#e2e2e2",
    overflow: "hidden",
  },
  scrubberFill: {
    height: 3,
    borderRadius: 2,
    backgroundColor: "#004ac6",
  },
  timestamps: {
    flexDirection: "row",
    justifyContent: "space-between",
  },
  timestampText: {
    fontFamily: "Manrope",
    fontSize: 12,
    fontWeight: "700",
    letterSpacing: 0.5,
    color: "#434655",
  },
  controls: {
    marginTop: 16,
    flexDirection: "row",
    justifyContent: "center",
    alignItems: "center",
    gap: 24,
  },
  skipButton: {
    padding: 12,
  },
  skipText: {
    fontFamily: "Manrope",
    fontSize: 14,
    fontWeight: "600",
    color: "#1a1c1c",
  },
  playButton: {
    width: 88,
    height: 88,
    borderRadius: 44,
    backgroundColor: "#004ac6",
    alignItems: "center",
    justifyContent: "center",
  },
  playIcon: {
    fontSize: 32,
    color: "#ffffff",
  },
});
