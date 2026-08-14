import React from "react";
import { NavigationContainer } from "@react-navigation/native";
import { createNativeStackNavigator } from "@react-navigation/native-stack";
import { HomeScreen } from "../screens/HomeScreen";
import { ModeScreen } from "../screens/ModeScreen";

export type RootStackParamList = {
  Home: undefined;
  Mode: undefined;
};

const Stack = createNativeStackNavigator<RootStackParamList>();

export function RootNavigator(): React.JSX.Element {
  return (
    <NavigationContainer>
      <Stack.Navigator initialRouteName="Home">
        <Stack.Screen name="Home" component={HomeScreen} options={{ title: "Ridewise" }} />
        <Stack.Screen name="Mode" component={ModeScreen} options={{ title: "Transport" }} />
      </Stack.Navigator>
    </NavigationContainer>
  );
}
