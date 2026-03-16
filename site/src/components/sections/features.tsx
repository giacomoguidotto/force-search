"use client";

import { Brain, Keyboard, MousePointerClick, Search } from "lucide-react";
import { motion } from "motion/react";
import { Spotlight } from "@/components/ui/spotlight";
import { cardHover, fadeUp, staggerContainer, staggerItem } from "@/lib/motion";

const features = [
  {
    icon: Search,
    title: "Multi-Provider Search",
    description: "Google, DuckDuckGo, Wikipedia. Switch with Cmd+1/2/3.",
  },
  {
    icon: Brain,
    title: "AI Analysis",
    description:
      "Claude, OpenAI, or local Ollama. Screenshot context + text understanding.",
  },
  {
    icon: MousePointerClick,
    title: "Smart Triggers",
    description: "Force-click, global hotkey, or double-tap a modifier key.",
  },
  {
    icon: Keyboard,
    title: "Keyboard-First",
    description: "Esc to close, Cmd+Return to open in browser, Cmd+C to copy.",
  },
];

export function Features() {
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
          Everything at your fingertips
        </motion.h2>

        <motion.div
          className="mt-16 grid gap-6 sm:grid-cols-2"
          initial="hidden"
          variants={staggerContainer}
          viewport={{ once: true, margin: "-100px" }}
          whileInView="show"
        >
          {features.map((feature) => (
            <motion.div key={feature.title} variants={staggerItem}>
              <Spotlight className="rounded-xl">
                <motion.div
                  className="glass rounded-xl border border-border bg-card/60 p-8"
                  initial="rest"
                  variants={cardHover}
                  whileHover="hover"
                  whileTap="tap"
                >
                  <feature.icon className="h-8 w-8 text-primary" />
                  <h3 className="mt-4">{feature.title}</h3>
                  <p className="mt-2 text-muted-foreground">
                    {feature.description}
                  </p>
                </motion.div>
              </Spotlight>
            </motion.div>
          ))}
        </motion.div>
      </div>
    </section>
  );
}
