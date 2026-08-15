import React, { useState } from "react";
import { StyleSheet, Text, TextInput, View } from "react-native";
import { PrimaryButton } from "../../components/PrimaryButton";

type TripFormProps = {
  onContinue: (startLabel: string, endLabel: string) => void;
};

export function TripForm({ onContinue }: TripFormProps): React.JSX.Element {
  const [startLabel, setStartLabel] = useState("");
  const [endLabel, setEndLabel] = useState("");
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
    setError(null);
    onContinue(startLabel, endLabel);
  }

  return (
    <View style={styles.container}>
      <Text style={styles.label}>Start</Text>
      <TextInput
        accessibilityLabel="Start"
        style={styles.input}
        value={startLabel}
        onChangeText={setStartLabel}
        placeholder="e.g. Rajiv Chowk"
      />

      <Text style={styles.label}>Destination</Text>
      <TextInput
        accessibilityLabel="Destination"
        style={styles.input}
        value={endLabel}
        onChangeText={setEndLabel}
        placeholder="e.g. Hauz Khas"
      />

      {error !== null ? <Text style={styles.error}>{error}</Text> : null}

      <PrimaryButton label="Continue" onPress={handleContinue} />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    gap: 8,
  },
  label: {
    fontSize: 14,
    fontWeight: "600",
    color: "#111827",
  },
  input: {
    borderWidth: 1,
    borderColor: "#D1D5DB",
    borderRadius: 8,
    paddingHorizontal: 12,
    paddingVertical: 10,
    fontSize: 16,
  },
  error: {
    color: "#DC2626",
    fontSize: 14,
  },
});
