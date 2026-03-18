import { NextResponse } from "next/server";

const REPO = "giacomoguidotto/scry";

export async function GET() {
  const res = await fetch(
    `https://api.github.com/repos/${REPO}/releases/latest`,
    { next: { revalidate: 300 } },
  );

  if (!res.ok) {
    return NextResponse.redirect(
      `https://github.com/${REPO}/releases/latest`,
    );
  }

  const release = await res.json();
  const dmg = release.assets?.find((a: { name: string }) =>
    a.name.endsWith(".dmg"),
  );

  if (!dmg) {
    return NextResponse.redirect(
      `https://github.com/${REPO}/releases/latest`,
    );
  }

  return NextResponse.redirect(dmg.browser_download_url);
}
