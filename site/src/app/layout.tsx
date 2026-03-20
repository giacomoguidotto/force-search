import type { Metadata } from "next";
import { Inter, Space_Grotesk } from "next/font/google";
import { ThemeProvider } from "@/components/providers/theme-provider";
import "./globals.css";

const display = Space_Grotesk({
  subsets: ["latin"],
  variable: "--font-display",
  display: "swap",
});

const sans = Inter({
  subsets: ["latin"],
  variable: "--font-sans",
  display: "swap",
});

export const metadata: Metadata = {
  title: "Scry | Instant multi-provider search for macOS",
  description:
    "Replace macOS Look Up with instant search. Google, DuckDuckGo, Wikipedia, AI, right where you clicked.",
  metadataBase: new URL("https://scry.guidotto.dev"),
  icons: {
    icon: "/favicon.png",
    apple: "/apple-touch-icon.png",
  },
  openGraph: {
    title: "Scry | Instant multi-provider search for macOS",
    description:
      "Replace macOS Look Up with instant search. Google, DuckDuckGo, Wikipedia, AI, right where you clicked.",
    type: "website",
    url: "https://scry.guidotto.dev",
  },
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body
        className={`${display.variable} ${sans.variable} font-sans antialiased`}
      >
        <ThemeProvider>{children}</ThemeProvider>
      </body>
    </html>
  );
}
