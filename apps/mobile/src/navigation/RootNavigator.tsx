import React from "react";
import { NavigationContainer } from "@react-navigation/native";
import { createNativeStackNavigator } from "@react-navigation/native-stack";
import type { Capsule } from "@commute-capsule/domain";
import { HomeScreen } from "../screens/HomeScreen";
import { ModeScreen } from "../screens/ModeScreen";
import { TripCheckScreen } from "../screens/TripCheckScreen";
import { TopicScreen } from "../screens/TopicScreen";

export type RootStackParamList = {
  Home: undefined;
  Mode: undefined;
  TripCheck: undefined;
  Topic: undefined;
  // ponytail: Player screen is built in a later task; this param type lets Topic
  // navigate to it now without a placeholder component.
  Player: { capsule: Capsule };
};

const Stack = createNativeStackNavigator<RootStackParamList>();

export function RootNavigator(): React.JSX.Element {
  return (
    <NavigationContainer>
      <Stack.Navigator initialRouteName="Home">
        <Stack.Screen name="Home" component={HomeScreen} options={{ title: "Ridewise" }} />
        <Stack.Screen name="Mode" component={ModeScreen} options={{ title: "Transport" }} />
        <Stack.Screen
          name="TripCheck"
          component={TripCheckScreen}
          options={{ title: "Trip Check" }}
        />
        <Stack.Screen name="Topic" component={TopicScreen} options={{ title: "Topic" }} />
      </Stack.Navigator>
    </NavigationContainer>
  );
}
