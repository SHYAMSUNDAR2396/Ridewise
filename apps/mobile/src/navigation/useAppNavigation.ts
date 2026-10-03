import { useNavigation } from "@react-navigation/native";
import type { RootStackParamList, TabParamList } from "./RootNavigator";

type RouteName = keyof RootStackParamList | keyof TabParamList;

/** Tab and stack screens navigate across both navigators, so params are checked by the screens themselves. */
export type AppNavigation = {
  navigate: (name: RouteName, params?: unknown) => void;
  goBack: () => void;
};

export function useAppNavigation(): AppNavigation {
  return useNavigation() as unknown as AppNavigation;
}
