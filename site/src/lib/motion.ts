import type { Transition, Variants } from "motion/react";

/** Spring presets for consistent motion feel */
export const spring = {
  gentle: { type: "spring", stiffness: 120, damping: 14 } as Transition,
  snappy: { type: "spring", stiffness: 300, damping: 24 } as Transition,
  bouncy: { type: "spring", stiffness: 400, damping: 10 } as Transition,
} as const;

/** Stagger container — use with staggerItem on children */
export const staggerContainer: Variants = {
  hidden: { opacity: 0 },
  show: {
    opacity: 1,
    transition: { staggerChildren: 0.06, delayChildren: 0.1 },
  },
};

/** Stagger item — blur-deblur entrance */
export const staggerItem: Variants = {
  hidden: { opacity: 0, y: 20, filter: "blur(4px)" },
  show: {
    opacity: 1,
    y: 0,
    filter: "blur(0px)",
    transition: { type: "spring", stiffness: 200, damping: 20 },
  },
};

/** Fade up — page sections */
export const fadeUp: Variants = {
  hidden: { opacity: 0, y: 30, filter: "blur(8px)" },
  show: {
    opacity: 1,
    y: 0,
    filter: "blur(0px)",
    transition: { type: "spring", stiffness: 150, damping: 20 },
  },
};

/** Scale in — badges, buttons appearing */
export const scaleIn: Variants = {
  hidden: { opacity: 0, scale: 0.85, filter: "blur(4px)" },
  show: {
    opacity: 1,
    scale: 1,
    filter: "blur(0px)",
    transition: { type: "spring", stiffness: 300, damping: 20 },
  },
};

/** Card hover — subtle lift + scale */
export const cardHover: Variants = {
  rest: { scale: 1, y: 0 },
  hover: {
    scale: 1.02,
    y: -6,
    transition: { type: "spring", stiffness: 300, damping: 20 },
  },
  tap: { scale: 0.98 },
};
