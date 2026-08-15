import React from "react";
import { Pressable, StyleSheet, Text, View } from "react-native";

export type RetryNoticeProps = {
  /** Short bold first line, e.g. "Couldn't estimate this route." */
  headline: string;
  /** Explanatory second line. */
  message: string;
  actionLabel: string;
  onRetry: () => void;
  /** A single character/emoji shown in the leading icon circle. */
  icon?: string;
  /** Extra content rendered between the message and the action button --
   *  e.g. TripCheckScreen's manual-duration input. */
  children?: React.ReactNode;
};

/**
 * Reusable failure/recovery card. Sourced from
 * stitch_ridewise_audio_companion_ui_ux/failure_states/code.html's
 * route-estimation-failure scenario (icon, headline, body, optional extra
 * content, action button) -- generic enough to also carry the
 * capsule-generation-failure and audio-unavailable message/action
 * combinations from the same component.
 */
export function RetryNotice({
  headline,
  message,
  actionLabel,
  onRetry,
  icon = "⚠",
  children,
}: RetryNoticeProps): React.JSX.Element {
  return (
    <View style={styles.card}>
      <View style={styles.accentBar} />
      <View style={styles.header}>
        <Text style={styles.icon}>{icon}</Text>
        <View style={styles.textColumn}>
          <Text style={styles.headline}>{headline}</Text>
          <Text style={styles.message}>{message}</Text>
        </View>
      </View>
      {children}
      <Pressable accessibilityRole="button" style={styles.button} onPress={onRetry}>
        <Text style={styles.buttonText}>{actionLabel}</Text>
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  card: {
    backgroundColor: "#ffffff",
    borderWidth: 1,
    borderColor: "#c3c6d7",
    borderRadius: 12,
    padding: 24,
    gap: 12,
    position: "relative",
    overflow: "hidden",
  },
  accentBar: {
    position: "absolute",
    top: 0,
    left: 0,
    bottom: 0,
    width: 4,
    backgroundColor: "#ba1a1a",
  },
  header: {
    flexDirection: "row",
    alignItems: "flex-start",
    gap: 12,
  },
  icon: {
    fontSize: 18,
    color: "#ba1a1a",
    marginTop: 2,
  },
  textColumn: {
    flex: 1,
    gap: 4,
  },
  headline: {
    fontFamily: "Manrope",
    fontSize: 18,
    color: "#1a1c1c",
  },
  message: {
    fontFamily: "Manrope",
    fontSize: 16,
    color: "#434655",
  },
  button: {
    marginTop: 8,
    width: "100%",
    borderRadius: 8,
    paddingVertical: 12,
    alignItems: "center",
    backgroundColor: "#2563eb",
  },
  buttonText: {
    fontFamily: "Manrope",
    fontSize: 13,
    fontWeight: "700",
    letterSpacing: 0.5,
    textTransform: "uppercase",
    color: "#ffffff",
  },
});
