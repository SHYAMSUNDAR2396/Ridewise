import React from "react";
import { Pressable, StyleSheet, Text, View } from "react-native";
import TrackPlayer, { State, usePlaybackState } from "react-native-track-player";
import { useCapsuleStore, type StoredCapsule } from "../features/capsules/capsule-store";
import { useNowPlaying } from "../features/capsules/now-playing";
import { colors } from "../theme";
import { Artwork } from "./Artwork";
import { Icon } from "./Icon";

function formatRemaining(capsule: StoredCapsule): string {
  const left = Math.max(0, Math.round(capsule.audioSeconds - capsule.progressSeconds));
  const minutes = Math.floor(left / 60);
  const seconds = left % 60;
  return `${minutes}:${seconds.toString().padStart(2, "0")} left`;
}

export function MiniPlayer({
  onOpen,
}: {
  onOpen: (capsule: StoredCapsule) => void;
}): React.JSX.Element | null {
  const capsuleId = useNowPlaying((state) => state.capsuleId);
  const capsule = useCapsuleStore((state) => state.capsules.find((item) => item.id === capsuleId));
  const playbackState = usePlaybackState();
  const isPlaying = playbackState.state === State.Playing;

  if (!capsule) return null;

  return (
    <View style={styles.bar}>
      <Pressable
        accessibilityRole="button"
        accessibilityLabel={`Open player, ${capsule.title}`}
        style={styles.open}
        onPress={() => onOpen(capsule)}
      >
        <Artwork seed={capsule.id} size={44} radius={8} />
        <View style={styles.text}>
          <Text style={styles.title} numberOfLines={1}>
            {capsule.title}
          </Text>
          <Text style={styles.meta}>{formatRemaining(capsule)}</Text>
        </View>
      </Pressable>
      <Pressable
        accessibilityRole="button"
        accessibilityLabel={isPlaying ? "Pause" : "Play"}
        style={styles.toggle}
        onPress={() => (isPlaying ? TrackPlayer.pause() : TrackPlayer.play())}
      >
        <Icon name={isPlaying ? "pause" : "play"} size={22} color={colors.text} />
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  bar: {
    marginHorizontal: 12,
    marginBottom: 8,
    height: 60,
    borderRadius: 14,
    backgroundColor: colors.surface,
    borderWidth: 1,
    borderColor: colors.line,
    flexDirection: "row",
    alignItems: "center",
    paddingLeft: 8,
    paddingRight: 6,
  },
  open: { flex: 1, flexDirection: "row", alignItems: "center", gap: 12, minHeight: 44 },
  text: { flex: 1 },
  title: { fontSize: 14, fontWeight: "700", color: colors.text },
  meta: { fontSize: 12, color: colors.textMuted },
  toggle: { width: 44, height: 44, alignItems: "center", justifyContent: "center" },
});
