import { Footer } from "@/components/layout/footer";
import { Navbar } from "@/components/layout/navbar";
import { Download } from "@/components/sections/download";
import { Features } from "@/components/sections/features";
import { Hero } from "@/components/sections/hero";
import { HowItWorks } from "@/components/sections/how-it-works";
import { OpenSource } from "@/components/sections/open-source";
import { Providers } from "@/components/sections/providers";

export default function Home() {
  return (
    <>
      <Navbar />
      <main>
        <Hero />
        <Features />
        <HowItWorks />
        <Providers />
        <OpenSource />
        <Download />
      </main>
      <Footer />
    </>
  );
}
