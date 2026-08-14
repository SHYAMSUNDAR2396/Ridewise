import React from "react";
import type { NativeStackScreenProps } from "@react-navigation/native-stack";
import { SafeAreaView, ScrollView, StyleSheet, Text } from "react-native";
import { TripForm } from "../features/trip/trip-form";
import { useTripStore } from "../features/trip/trip-store";
import type { RootStackParamList } from "../navigation/RootNavigator";

type HomeScreenProps = NativeStackScreenProps<RootStackParamList, "Home">;

export function HomeScreen({ navigation }: HomeScreenProps): React.JSX.Element {
  const setEndpoints = useTripStore((state) => state.setEndpoints);

  function handleContinue(startLabel: string, endLabel: string): void {
    setEndpoints(startLabel, endLabel);
    navigation.navigate("Mode");
  }

  return (
    <SafeAreaView style={styles.container}>
      <ScrollView contentContainerStyle={styles.content}>
        <Text style={styles.title}>Where are you headed?</Text>
        <TripForm onContinue={handleContinue} />
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: "#FFFFFF",
  },
  content: {
    padding: 20,
    gap: 16,
  },
  title: {
    fontSize: 22,
    fontWeight: "700",
    color: "#111827",
  },
});
