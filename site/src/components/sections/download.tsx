"use client";

import { Download as DownloadIcon } from "lucide-react";
import { motion } from "motion/react";
import { Badge } from "@/components/ui/badge";
import { ButtonLink } from "@/components/ui/button";
import { staggerContainer, staggerItem } from "@/lib/motion";

export function Download() {
  return (
    <section className="relative px-6 py-24 md:py-32">
      {/* Glow behind CTA */}
      <div
        aria-hidden
        className="pointer-events-none absolute bottom-1/2 left-1/2 h-[400px] w-[400px] -translate-x-1/2 translate-y-1/2 rounded-full opacity-15"
        style={{
          background:
            "radial-gradient(circle, oklch(0.82 0.14 170 / 50%), transparent 70%)",
          filter: "blur(80px)",
        }}
      />

      <motion.div
        className="relative z-10 mx-auto flex max-w-2xl flex-col items-center text-center"
        initial="hidden"
        variants={staggerContainer}
        viewport={{ once: true, margin: "-100px" }}
        whileInView="show"
      >
        <motion.h2 variants={staggerItem}>Get Scry</motion.h2>

        <motion.div
          className="mt-4 flex flex-wrap items-center justify-center gap-2"
          variants={staggerItem}
        >
          <Badge variant="outline">macOS 13+</Badge>
          <Badge variant="outline">Accessibility permission</Badge>
          <Badge variant="outline">Screen Recording (optional)</Badge>
        </motion.div>

        <motion.div className="mt-8" variants={staggerItem}>
          <ButtonLink
            href="https://github.com/giacomoguidotto/scry/releases/latest"
            rel="noopener noreferrer"
            size="lg"
            target="_blank"
          >
            <DownloadIcon className="h-5 w-5" />
            Download for macOS
          </ButtonLink>
        </motion.div>

        <motion.p
          className="mt-6 text-muted-foreground text-sm"
          variants={staggerItem}
        >
          First launch: right-click → Open to bypass Gatekeeper.
        </motion.p>
      </motion.div>
    </section>
  );
}
