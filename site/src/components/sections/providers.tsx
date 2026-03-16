"use client";

import { Bot, Globe, Search } from "lucide-react";
import { motion } from "motion/react";
import { fadeUp, staggerContainer, staggerItem } from "@/lib/motion";

const providers = [
  { name: "Google", icon: Globe },
  { name: "DuckDuckGo", icon: Search },
  { name: "Wikipedia", icon: Globe },
  { name: "Claude", icon: Bot },
  { name: "OpenAI", icon: Bot },
  { name: "Ollama", icon: Bot },
];

export function Providers() {
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
          Your search, your way
        </motion.h2>

        <motion.div
          className="mt-16 flex flex-wrap items-center justify-center gap-4"
          initial="hidden"
          variants={staggerContainer}
          viewport={{ once: true, margin: "-100px" }}
          whileInView="show"
        >
          {providers.map((provider) => (
            <motion.div
              className="glass flex items-center gap-3 rounded-xl border border-border bg-card/60 px-6 py-4 transition-colors hover:border-primary/30 hover:bg-muted"
              key={provider.name}
              variants={staggerItem}
            >
              <provider.icon className="h-5 w-5 text-muted-foreground" />
              <span className="font-medium">{provider.name}</span>
            </motion.div>
          ))}
        </motion.div>

        <motion.p
          className="mt-8 text-center text-muted-foreground text-sm"
          initial="hidden"
          variants={fadeUp}
          viewport={{ once: true, margin: "-100px" }}
          whileInView="show"
        >
          AI providers require an API key. Local Ollama is free.
        </motion.p>
      </div>
    </section>
  );
}
