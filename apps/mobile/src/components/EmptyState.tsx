import React from "react";
import { StyleSheet, Text, View } from "react-native";

export type EmptyStateProps = {
  title: string;
  message?: string;
  icon?: string;
};

/** Reusable empty-state placeholder for a list with nothing in it yet. */
export function EmptyState({ title, message, icon = "🎧" }: EmptyStateProps): React.JSX.Element {
  return (
    <View style={styles.container}>
      <Text style={styles.icon}>{icon}</Text>
      <Text style={styles.title}>{title}</Text>
      {message ? <Text style={styles.message}>{message}</Text> : null}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    alignItems: "center",
    justifyContent: "center",
    paddingVertical: 64,
    paddingHorizontal: 32,
    gap: 8,
  },
  icon: {
    fontSize: 32,
    marginBottom: 4,
  },
  title: {
    fontFamily: "Newsreader",
    fontSize: 20,
    fontWeight: "500",
    color: "#1a1c1c",
    textAlign: "center",
  },
  message: {
    fontFamily: "Manrope",
    fontSize: 14,
    color: "#434655",
    textAlign: "center",
  },
});
