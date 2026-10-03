import React from "react";
import { Pressable, StyleSheet, Text } from "react-native";
import { colors } from "../theme";

type ChipProps = {
  label: string;
  selected: boolean;
  onPress: () => void;
  role?: "button" | "tab";
};

export function Chip({ label, selected, onPress, role = "button" }: ChipProps): React.JSX.Element {
  return (
    <Pressable
      accessibilityRole={role}
      accessibilityLabel={label}
      accessibilityState={{ selected }}
      onPress={onPress}
      style={[styles.chip, selected && styles.chipSelected]}
    >
      <Text style={[styles.label, selected && styles.labelSelected]}>{label}</Text>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  chip: {
    height: 44,
    paddingHorizontal: 16,
    borderRadius: 22,
    backgroundColor: colors.surface,
    alignItems: "center",
    justifyContent: "center",
  },
  chipSelected: { backgroundColor: colors.accent },
  label: { fontSize: 14, fontWeight: "700", color: colors.text },
  labelSelected: { color: colors.onAccent },
});
