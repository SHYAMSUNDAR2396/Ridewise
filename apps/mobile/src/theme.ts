import { Platform } from "react-native";

export const colors = {
  bg: "#ffffff",
  surface: "#f0f1f4",
  line: "#e7e8ec",
  text: "#16181d",
  textMuted: "#5b6270",
  accent: "#2563eb",
  accentSoft: "#e8efff",
  accentInk: "#1e3a8a",
  onAccent: "#ffffff",
  danger: "#ba1a1a",
  playerTop: "#1d4ed8",
  playerMid: "#1e1b8f",
  playerBottom: "#0f1030",
  onPlayer: "#ffffff",
  onPlayerMuted: "rgba(255,255,255,0.78)",
  onPlayerFaint: "rgba(255,255,255,0.28)",
} as const;

// Newsreader and Manrope are not bundled yet; these are the closest system faces.
export const fonts = {
  serif: Platform.select({ ios: "Georgia", default: "serif" }),
};

export const artworkPalettes = [
  { from: "#2563eb", to: "#1e1b8f" },
  { from: "#f59e0b", to: "#b45309" },
  { from: "#10b981", to: "#065f46" },
  { from: "#ec4899", to: "#7c1d6f" },
  { from: "#0ea5e9", to: "#0f3d6b" },
  { from: "#8b5cf6", to: "#3b1d8f" },
] as const;
