"use client";

import { motion } from "motion/react";
import { Badge } from "@/components/ui/badge";
import { ButtonLink } from "@/components/ui/button";
import { staggerContainer, staggerItem } from "@/lib/motion";

export function Hero() {
  return (
    <section className="relative flex min-h-screen items-center justify-center overflow-hidden px-6 pt-16">
      {/* Radial glow behind headline */}
      <div
        aria-hidden
        className="pointer-events-none absolute top-1/3 left-1/2 h-[600px] w-[600px] -translate-x-1/2 -translate-y-1/2 rounded-full opacity-20"
        style={{
          background:
            "radial-gradient(circle, oklch(0.82 0.14 170 / 40%), transparent 70%)",
          filter: "blur(80px)",
        }}
      />

      <motion.div
        animate="show"
        className="relative z-10 mx-auto flex max-w-4xl flex-col items-center text-center"
        initial="hidden"
        variants={staggerContainer}
      >
        <motion.div variants={staggerItem}>
          <Badge>Open Source</Badge>
        </motion.div>

        <motion.h1 className="mt-6" variants={staggerItem}>
          See through any text
        </motion.h1>

        <motion.p
          className="mt-6 max-w-2xl text-lg text-muted-foreground md:text-xl"
          variants={staggerItem}
        >
          Replace macOS&apos;s Look Up with instant search. Google, Wikipedia,
          AI, right where you clicked.
        </motion.p>

        <motion.div
          className="mt-8 flex flex-wrap items-center justify-center gap-4"
          variants={staggerItem}
        >
          <ButtonLink href="/api/download" size="lg">
            Download for macOS
          </ButtonLink>
          <ButtonLink
            href="https://github.com/giacomoguidotto/scry"
            rel="noopener noreferrer"
            size="lg"
            target="_blank"
            variant="secondary"
          >
            View on GitHub
          </ButtonLink>
        </motion.div>

        {/* IMAGE: Hero screenshot of the Scry panel appearing over text */}
        <motion.div className="mt-16 w-full max-w-3xl" variants={staggerItem}>
          <div className="glass flex aspect-video items-center justify-center rounded-xl border border-border bg-card/40 text-muted-foreground">
            {/* IMAGE: Screenshot of Scry panel in action — force-click on a word showing search results */}
          </div>
        </motion.div>
      </motion.div>
    </section>
  );
}
