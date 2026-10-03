import React from "react";
import { Pressable, StyleSheet, Text, TextInput, View } from "react-native";
import { Icon } from "../../components/Icon";
import { colors, fonts } from "../../theme";

type DurationStepperProps = {
  minutes: number;
  onChangeMinutes: (minutes: number) => void;
  onUseManualTime: () => void;
};

export function DurationStepper({
  minutes,
  onChangeMinutes,
  onUseManualTime,
}: DurationStepperProps): React.JSX.Element {
  function decrease(): void {
    if (minutes > 1) onChangeMinutes(minutes - 1);
  }

  function increase(): void {
    onChangeMinutes(minutes + 1);
  }

  function handleTextChange(text: string): void {
    const parsed = parseInt(text, 10);
    if (!Number.isNaN(parsed)) onChangeMinutes(parsed);
  }

  return (
    <View style={styles.container}>
      <Text style={styles.headline}>About {minutes} minutes</Text>
      <Text style={styles.helper}>Adjust this if your ride usually takes longer or shorter.</Text>
      <View style={styles.stepperRow}>
        <Pressable
          accessibilityRole="button"
          accessibilityLabel="Decrease minutes"
          style={styles.stepperButton}
          onPress={decrease}
        >
          <Icon name="minus" size={20} color={colors.text} />
        </Pressable>
        <TextInput
          accessibilityLabel="Minutes"
          style={styles.stepperInput}
          keyboardType="numeric"
          value={String(minutes)}
          onChangeText={handleTextChange}
        />
        <Pressable
          accessibilityRole="button"
          accessibilityLabel="Increase minutes"
          style={styles.stepperButton}
          onPress={increase}
        >
          <Icon name="plus" size={20} color={colors.text} />
        </Pressable>
      </View>
      <Pressable accessibilityRole="button" onPress={onUseManualTime} style={styles.manualLinkWrap}>
        <Text style={styles.manualLink}>Use manual time</Text>
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { alignItems: "center", gap: 12, paddingVertical: 16 },
  headline: { fontFamily: fonts.serif, fontSize: 30, fontWeight: "700", color: colors.accent, textAlign: "center" },
  helper: { fontSize: 15, color: colors.textMuted, textAlign: "center", maxWidth: 260 },
  stepperRow: { flexDirection: "row", alignItems: "center", gap: 20, marginTop: 8 },
  stepperButton: {
    width: 56,
    height: 56,
    borderRadius: 28,
    backgroundColor: colors.surface,
    alignItems: "center",
    justifyContent: "center",
  },
  stepperInput: {
    width: 96,
    textAlign: "center",
    fontFamily: fonts.serif,
    fontSize: 40,
    fontWeight: "700",
    color: colors.text,
    paddingVertical: 4,
  },
  manualLinkWrap: { minHeight: 44, justifyContent: "center", paddingHorizontal: 12 },
  manualLink: { fontSize: 13, fontWeight: "800", letterSpacing: 0.6, textTransform: "uppercase", color: colors.accent },
});
