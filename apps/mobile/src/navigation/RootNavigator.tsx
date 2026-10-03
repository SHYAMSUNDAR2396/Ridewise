import React from "react";
import { NavigationContainer } from "@react-navigation/native";
import { createNativeStackNavigator } from "@react-navigation/native-stack";
import { createBottomTabNavigator } from "@react-navigation/bottom-tabs";
import type { Capsule } from "@commute-capsule/domain";
import { HomeScreen } from "../screens/HomeScreen";
import { PlanScreen } from "../screens/PlanScreen";
import { TripCheckScreen } from "../screens/TripCheckScreen";
import { TopicScreen } from "../screens/TopicScreen";
import { PlayerScreen } from "../screens/PlayerScreen";
import { LibraryScreen } from "../screens/LibraryScreen";
import { TabBar } from "./TabBar";

export type RootStackParamList = {
  Tabs: undefined;
  TripCheck: undefined;
  Topic: undefined;
  Player: { capsule: Capsule };
};

export type TabParamList = {
  ListenNow: undefined;
  Plan: undefined;
  Library: undefined;
};

const Stack = createNativeStackNavigator<RootStackParamList>();
const Tabs = createBottomTabNavigator<TabParamList>();

function TabsNavigator(): React.JSX.Element {
  return (
    <Tabs.Navigator
      initialRouteName="ListenNow"
      tabBar={(props) => <TabBar {...props} />}
      screenOptions={{ headerShown: false }}
    >
      <Tabs.Screen name="ListenNow" component={HomeScreen} />
      <Tabs.Screen name="Plan" component={PlanScreen} />
      <Tabs.Screen name="Library" component={LibraryScreen} />
    </Tabs.Navigator>
  );
}

export function RootNavigator(): React.JSX.Element {
  return (
    <NavigationContainer>
      <Stack.Navigator initialRouteName="Tabs">
        <Stack.Screen name="Tabs" component={TabsNavigator} options={{ headerShown: false }} />
        <Stack.Screen
          name="TripCheck"
          component={TripCheckScreen}
          options={{ title: "", headerBackTitle: "Plan", headerShadowVisible: false }}
        />
        <Stack.Screen
          name="Topic"
          component={TopicScreen}
          options={{ title: "", headerBackTitle: "Trip", headerShadowVisible: false }}
        />
        <Stack.Screen
          name="Player"
          component={PlayerScreen}
          options={{ headerShown: false, presentation: "modal" }}
        />
      </Stack.Navigator>
    </NavigationContainer>
  );
}
