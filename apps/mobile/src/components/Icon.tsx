import React from "react";
import Svg, { Circle, Path, Rect, Text as SvgText } from "react-native-svg";

export type IconName =
  | "headphones"
  | "route"
  | "library"
  | "person"
  | "back"
  | "play"
  | "pause"
  | "more"
  | "check"
  | "download"
  | "chevron"
  | "transcript"
  | "bookmark"
  | "back10"
  | "forward30"
  | "plus"
  | "minus"
  | "edit"
  | "close"
  | "alert"
  | "lock";

type IconProps = { name: IconName; size?: number; color: string };

export function Icon({ name, size = 24, color }: IconProps): React.JSX.Element {
  const stroke = {
    fill: "none",
    stroke: color,
    strokeWidth: 2,
    strokeLinecap: "round" as const,
    strokeLinejoin: "round" as const,
  };

  return (
    <Svg width={size} height={size} viewBox="0 0 24 24" accessibilityElementsHidden>
      {name === "headphones" && (
        <Path {...stroke} d="M4 14v-2a8 8 0 0116 0v2M4 14h3v6H5a1 1 0 01-1-1v-5zM20 14h-3v6h2a1 1 0 001-1v-5z" />
      )}
      {name === "route" && (
        <>
          <Circle {...stroke} cx="6" cy="18" r="2.2" />
          <Circle {...stroke} cx="18" cy="6" r="2.2" />
          <Path {...stroke} d="M8.2 18h6.3a3.5 3.5 0 000-7H9.5a3.5 3.5 0 010-7h6.3" />
        </>
      )}
      {name === "library" && (
        <>
          <Rect {...stroke} x="4" y="4" width="4" height="16" rx="1" />
          <Rect {...stroke} x="10" y="4" width="4" height="16" rx="1" />
          <Path {...stroke} d="M16.5 5.5l3.2-.8 3 14-3.2.8z" />
        </>
      )}
      {name === "person" && (
        <>
          <Circle {...stroke} cx="12" cy="8" r="3.6" />
          <Path {...stroke} d="M5 20c.8-4 3.6-6 7-6s6.2 2 7 6" />
        </>
      )}
      {name === "back" && <Path {...stroke} strokeWidth={2.4} d="M15 5l-7 7 7 7" />}
      {name === "chevron" && <Path {...stroke} strokeWidth={2.6} d="M9 5l7 7-7 7" />}
      {name === "play" && <Path fill={color} d="M7 4.5v15l13-7.5z" />}
      {name === "pause" && (
        <>
          <Rect fill={color} x="6" y="4.5" width="4.2" height="15" rx="1" />
          <Rect fill={color} x="13.8" y="4.5" width="4.2" height="15" rx="1" />
        </>
      )}
      {name === "more" && (
        <>
          <Circle fill={color} cx="5" cy="12" r="1.8" />
          <Circle fill={color} cx="12" cy="12" r="1.8" />
          <Circle fill={color} cx="19" cy="12" r="1.8" />
        </>
      )}
      {name === "check" && (
        <>
          <Circle {...stroke} strokeWidth={2.2} cx="12" cy="12" r="9" />
          <Path {...stroke} strokeWidth={2.2} d="M8 12.5l2.7 2.7L16.5 9.5" />
        </>
      )}
      {name === "download" && <Path {...stroke} d="M12 4v11M7 11l5 5 5-5M5 20h14" />}
      {name === "transcript" && (
        <>
          <Rect {...stroke} x="4" y="5" width="16" height="12" rx="3" />
          <Path {...stroke} d="M8 20l3-3M8 10h8M8 13h5" />
        </>
      )}
      {name === "bookmark" && <Path {...stroke} d="M7 4h10a1 1 0 011 1v15l-6-4-6 4V5a1 1 0 011-1z" />}
      {name === "back10" && (
        <>
          <Path {...stroke} strokeWidth={1.8} d="M5 12a7 7 0 107-7H8.5M8.5 5.5L11.5 2.5M8.5 5.5l3 3" />
          <SvgText x="12" y="15.4" textAnchor="middle" fontSize="6.6" fontWeight="800" fill={color}>
            10
          </SvgText>
        </>
      )}
      {name === "forward30" && (
        <>
          <Path {...stroke} strokeWidth={1.8} d="M19 12a7 7 0 11-7-7h3.5M15.5 5.5L12.5 2.5M15.5 5.5l-3 3" />
          <SvgText x="12" y="15.4" textAnchor="middle" fontSize="6.6" fontWeight="800" fill={color}>
            30
          </SvgText>
        </>
      )}
      {name === "plus" && <Path {...stroke} strokeWidth={2.6} d="M12 5v14M5 12h14" />}
      {name === "minus" && <Path {...stroke} strokeWidth={2.6} d="M5 12h14" />}
      {name === "edit" && <Path {...stroke} d="M4 20h4L19 9l-4-4L4 16v4zM13.5 6.5l4 4" />}
      {name === "close" && <Path {...stroke} strokeWidth={2.4} d="M6 6l12 12M18 6L6 18" />}
      {name === "alert" && (
        <>
          <Circle {...stroke} cx="12" cy="12" r="9" />
          <Path {...stroke} d="M12 7.5v5.5M12 16.5v.01" />
        </>
      )}
      {name === "lock" && (
        <>
          <Rect {...stroke} x="5" y="11" width="14" height="9" rx="2" />
          <Path {...stroke} d="M8 11V8a4 4 0 018 0v3" />
        </>
      )}
    </Svg>
  );
}
