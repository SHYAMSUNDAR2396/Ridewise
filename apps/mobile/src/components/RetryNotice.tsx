import React from "react";
import { Pressable, StyleSheet, Text, View } from "react-native";
import { colors } from "../theme";
import { Icon, type IconName } from "./Icon";

export type RetryNoticeProps = {
  /** Short bold first line, e.g. "Couldn't estimate this route." */
  headline: string;
  /** Explanatory second line. */
  message: string;
  actionLabel: string;
  onRetry: () => void;
  icon?: IconName;
  /** Extra content between the message and the action, e.g. a manual-duration input. */
  children?: React.ReactNode;
};

/** Failure/recovery card: icon, headline, body, optional extra content, one action. */
export function RetryNotice({
  headline,
  message,
  actionLabel,
  onRetry,
  icon = "alert",
  children,
}: RetryNoticeProps): React.JSX.Element {
  return (
    <View style={styles.card}>
      <View style={styles.header}>
        <Icon name={icon} size={22} color={colors.danger} />
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
    backgroundColor: colors.surface,
    borderRadius: 18,
    padding: 20,
    gap: 12,
  },
  header: { flexDirection: "row", alignItems: "flex-start", gap: 12 },
  textColumn: { flex: 1, gap: 4 },
  headline: { fontSize: 17, fontWeight: "800", color: colors.text },
  message: { fontSize: 15, color: colors.textMuted },
  button: {
    marginTop: 4,
    height: 48,
    borderRadius: 24,
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: colors.accent,
  },
  buttonText: { fontSize: 15, fontWeight: "800", color: colors.onAccent },
});
