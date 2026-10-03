import React from "react";
import { StyleSheet, View } from "react-native";
import Svg, { Circle, Defs, LinearGradient, Path, Rect, Stop } from "react-native-svg";
import { artworkPalettes } from "../theme";

const ROUTES = [
  { d: "M-5 78 C25 78 25 38 52 38 S80 22 105 22", x: 52, y: 38 },
  { d: "M-5 30 C30 30 30 70 58 70 S85 55 105 60", x: 58, y: 70 },
  { d: "M-5 60 C20 60 30 25 55 30 S85 75 105 50", x: 55, y: 30 },
] as const;

function hash(seed: string): number {
  let value = 0;
  for (let i = 0; i < seed.length; i += 1) value = (value * 31 + seed.charCodeAt(i)) >>> 0;
  return value;
}

/** Fills its parent with a diagonal gradient. Parent must clip with overflow: hidden. */
export function GradientFill({
  from,
  to,
  id,
}: {
  from: string;
  to: string;
  id: string;
}): React.JSX.Element {
  return (
    <Svg style={StyleSheet.absoluteFill} width="100%" height="100%" preserveAspectRatio="none" viewBox="0 0 100 100">
      <Defs>
        <LinearGradient id={id} x1="0" y1="0" x2="1" y2="1">
          <Stop offset="0" stopColor={from} />
          <Stop offset="1" stopColor={to} />
        </LinearGradient>
      </Defs>
      <Rect width="100" height="100" fill={`url(#${id})`} />
    </Svg>
  );
}

/** Generated cover art: a gradient and a route line, chosen from the capsule's id. */
export function Artwork({
  seed,
  size,
  radius,
}: {
  seed: string;
  size: number;
  radius?: number;
}): React.JSX.Element {
  const value = hash(seed);
  const palette = artworkPalettes[value % artworkPalettes.length];
  const route = ROUTES[value % ROUTES.length];
  const gradientId = `art-${value}`;

  return (
    <View
      style={{
        width: size,
        height: size,
        borderRadius: radius ?? Math.round(size * 0.09),
        overflow: "hidden",
      }}
    >
      <Svg width={size} height={size} viewBox="0 0 100 100">
        <Defs>
          <LinearGradient id={gradientId} x1="0" y1="0" x2="1" y2="1">
            <Stop offset="0" stopColor={palette.from} />
            <Stop offset="1" stopColor={palette.to} />
          </LinearGradient>
        </Defs>
        <Rect width="100" height="100" fill={`url(#${gradientId})`} />
        <Path
          d={route.d}
          fill="none"
          stroke="#ffffff"
          strokeOpacity={0.6}
          strokeWidth={2.4}
          strokeLinecap="round"
        />
        <Circle cx={route.x} cy={route.y} r={4} fill="#ffffff" />
      </Svg>
    </View>
  );
}
