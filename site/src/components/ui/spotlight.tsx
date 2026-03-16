"use client";

import { useCallback, useRef, useState } from "react";
import { cn } from "@/lib/utils";

interface SpotlightProps {
  /** Blur radius in px. Defaults to 80. */
  blur?: number;
  children: React.ReactNode;
  className?: string;
  /** Color of the spotlight glow. Defaults to primary via CSS variable. */
  color?: string;
  /** Size of the spotlight in px. Defaults to 200. */
  size?: number;
}

/**
 * Spotlight wrapper — renders a blurred glow that follows the mouse on hover.
 * Wrap any card or container to add the effect.
 */
export function Spotlight({
  children,
  className,
  color = "oklch(from var(--primary) l c h / 20%)",
  blur = 80,
  size = 200,
}: SpotlightProps) {
  const ref = useRef<HTMLDivElement>(null);
  const [pos, setPos] = useState({ x: 0, y: 0 });
  const [isHovered, setIsHovered] = useState(false);

  const handleMouseMove = useCallback((e: React.MouseEvent<HTMLDivElement>) => {
    const rect = ref.current?.getBoundingClientRect();
    if (!rect) {
      return;
    }
    setPos({ x: e.clientX - rect.left, y: e.clientY - rect.top });
  }, []);

  const handleMouseEnter = useCallback(() => {
    setIsHovered(true);
  }, []);

  const handleMouseLeave = useCallback(() => {
    setIsHovered(false);
  }, []);

  return (
    // biome-ignore lint/a11y/noStaticElementInteractions: decorative visual effect only
    // biome-ignore lint/a11y/noNoninteractiveElementInteractions: mouse tracking for spotlight
    <div
      className={cn("relative overflow-hidden", className)}
      onMouseEnter={handleMouseEnter}
      onMouseLeave={handleMouseLeave}
      onMouseMove={handleMouseMove}
      ref={ref}
    >
      <div
        aria-hidden
        className="pointer-events-none absolute -translate-x-1/2 -translate-y-1/2 rounded-full"
        style={{
          left: pos.x,
          top: pos.y,
          width: size,
          height: size,
          background: `radial-gradient(circle, ${color}, transparent 70%)`,
          filter: `blur(${blur}px)`,
          opacity: isHovered ? 1 : 0,
          transition: "opacity 300ms ease",
        }}
      />
      <div className="relative">{children}</div>
    </div>
  );
}
