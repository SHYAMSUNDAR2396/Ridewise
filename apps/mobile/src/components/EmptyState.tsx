import React from "react";
import { StyleSheet, Text, View } from "react-native";
import { colors, fonts } from "../theme";
import { Icon } from "./Icon";

export type EmptyStateProps = {
  title: string;
  message?: string;
};

/** Reusable empty-state placeholder for a list with nothing in it yet. */
export function EmptyState({ title, message }: EmptyStateProps): React.JSX.Element {
  return (
    <View style={styles.container}>
      <Icon name="headphones" size={32} color={colors.textMuted} />
      <Text style={styles.title}>{title}</Text>
      {message ? <Text style={styles.message}>{message}</Text> : null}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    alignItems: "center",
    justifyContent: "center",
    paddingVertical: 48,
    paddingHorizontal: 32,
    gap: 8,
  },
  title: {
    fontFamily: fonts.serif,
    fontSize: 22,
    fontWeight: "700",
    color: colors.text,
    textAlign: "center",
    marginTop: 4,
  },
  message: { fontSize: 14, color: colors.textMuted, textAlign: "center" },
});
