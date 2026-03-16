"use client";

import { Hand, ScanText, Zap } from "lucide-react";
import { motion } from "motion/react";
import { fadeUp, staggerContainer, staggerItem } from "@/lib/motion";

const steps = [
  {
    icon: Hand,
    number: "1",
    title: "Trigger",
    description: "Force-click, press your hotkey, or double-tap a modifier.",
  },
  {
    icon: ScanText,
    number: "2",
    title: "Extract",
    description: "Scry grabs text via accessibility, clipboard, or OCR.",
  },
  {
    icon: Zap,
    number: "3",
    title: "Answer",
    description:
      "Results appear instantly in a floating panel. No app switching.",
  },
];

export function HowItWorks() {
  return (
    <section className="px-6 py-24 md:py-32">
      <div className="mx-auto max-w-6xl">
        <motion.h2
          className="text-center"
          initial="hidden"
          variants={fadeUp}
          viewport={{ once: true, margin: "-100px" }}
          whileInView="show"
        >
          Three steps, zero friction
        </motion.h2>

        <motion.div
          className="mt-16 grid gap-8 md:grid-cols-3"
          initial="hidden"
          variants={staggerContainer}
          viewport={{ once: true, margin: "-100px" }}
          whileInView="show"
        >
          {steps.map((step, i) => (
            <motion.div
              className="relative flex flex-col items-center text-center"
              key={step.title}
              variants={staggerItem}
            >
              {/* Connector line */}
              {i < steps.length - 1 && (
                <div
                  aria-hidden
                  className="absolute top-10 left-[calc(50%+2.5rem)] hidden h-px w-[calc(100%-5rem)] bg-border md:block"
                />
              )}

              <div className="glass flex h-20 w-20 items-center justify-center rounded-2xl border border-border bg-card/60">
                <step.icon className="h-8 w-8 text-primary" />
              </div>
              <span className="mt-4 font-display font-semibold text-primary text-sm">
                Step {step.number}
              </span>
              <h3 className="mt-1">{step.title}</h3>
              <p className="mt-2 max-w-xs text-muted-foreground">
                {step.description}
              </p>

              {/* IMAGE: Screenshot showing this step in action */}
              <div className="mt-6 w-full">
                <div className="glass flex aspect-[4/3] items-center justify-center rounded-lg border border-border bg-card/40 text-muted-foreground text-sm">
                  {/* IMAGE: {step.title} step screenshot */}
                </div>
              </div>
            </motion.div>
          ))}
        </motion.div>
      </div>
    </section>
  );
}
