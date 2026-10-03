import React, { useState } from "react";
import { StyleSheet, Text, TextInput, View } from "react-native";
import type { TransportMode } from "@commute-capsule/domain";
import { Chip } from "../../components/Chip";
import { PrimaryButton } from "../../components/PrimaryButton";
import { colors } from "../../theme";

const MODES: { mode: TransportMode; label: string }[] = [
  { mode: "metro", label: "Metro" },
  { mode: "bus", label: "Bus" },
  { mode: "local_train", label: "Local train" },
  { mode: "car", label: "Cab or car" },
  { mode: "bike", label: "Bike" },
  { mode: "walk", label: "Walk" },
  { mode: "other", label: "Other" },
];

type TripFormProps = {
  onContinue: (startLabel: string, endLabel: string, transportMode: TransportMode) => void;
};

export function TripForm({ onContinue }: TripFormProps): React.JSX.Element {
  const [startLabel, setStartLabel] = useState("");
  const [endLabel, setEndLabel] = useState("");
  const [mode, setMode] = useState<TransportMode | null>(null);
  const [error, setError] = useState<string | null>(null);

  function handleContinue(): void {
    if (startLabel.trim().length === 0) {
      setError("Enter a starting point");
      return;
    }
    if (endLabel.trim().length === 0) {
      setError("Enter a destination");
      return;
    }
    if (mode === null) {
      setError("Choose how you are travelling");
      return;
    }
    setError(null);
    onContinue(startLabel, endLabel, mode);
  }

  return (
    <View style={styles.container}>
      <View style={styles.card}>
        <View style={styles.rail}>
          <View style={styles.dotStart} />
          <View style={styles.line} />
          <View style={styles.dotEnd} />
        </View>
        <View style={styles.fields}>
          <View style={[styles.field, styles.fieldDivider]}>
            <Text style={styles.label}>FROM</Text>
            <TextInput
              accessibilityLabel="Start"
              style={styles.input}
              value={startLabel}
              onChangeText={setStartLabel}
              placeholder="e.g. Rajiv Chowk"
              placeholderTextColor={colors.textMuted}
            />
          </View>
          <View style={styles.field}>
            <Text style={styles.label}>TO</Text>
            <TextInput
              accessibilityLabel="Destination"
              style={styles.input}
              value={endLabel}
              onChangeText={setEndLabel}
              placeholder="e.g. Hauz Khas"
              placeholderTextColor={colors.textMuted}
            />
          </View>
        </View>
      </View>

      <Text style={styles.sectionLabel}>HOW ARE YOU TRAVELLING</Text>
      <View style={styles.chips}>
        {MODES.map((option) => (
          <Chip
            key={option.mode}
            label={option.label}
            selected={mode === option.mode}
            onPress={() => setMode(option.mode)}
          />
        ))}
      </View>

      {error !== null ? <Text style={styles.error}>{error}</Text> : null}

      <PrimaryButton label="Continue" onPress={handleContinue} />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { gap: 16 },
  card: {
    backgroundColor: colors.surface,
    borderRadius: 18,
    paddingVertical: 6,
    paddingHorizontal: 16,
    flexDirection: "row",
    gap: 12,
  },
  rail: { width: 14, alignItems: "center", paddingVertical: 28 },
  dotStart: { width: 10, height: 10, borderRadius: 5, backgroundColor: colors.accent },
  line: { flex: 1, borderLeftWidth: 2, borderStyle: "dotted", borderColor: "#9aa1b0", marginVertical: 4 },
  dotEnd: { width: 10, height: 10, borderRadius: 2, backgroundColor: colors.text },
  fields: { flex: 1 },
  field: { paddingVertical: 10 },
  fieldDivider: { borderBottomWidth: 1, borderBottomColor: "#dcdee4" },
  label: { fontSize: 12, fontWeight: "700", color: colors.textMuted, letterSpacing: 0.3 },
  input: { height: 32, padding: 0, fontSize: 17, fontWeight: "700", color: colors.text },
  sectionLabel: { fontSize: 13, fontWeight: "800", color: colors.textMuted, letterSpacing: 0.3 },
  chips: { flexDirection: "row", flexWrap: "wrap", gap: 8 },
  error: { color: colors.danger, fontSize: 14, fontWeight: "600" },
});
