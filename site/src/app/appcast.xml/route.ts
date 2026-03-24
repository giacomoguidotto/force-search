import { NextResponse } from "next/server";

const REPO = "giacomoguidotto/scry";

interface ReleaseAsset {
  name: string;
  size: number;
  browser_download_url: string;
}

interface Release {
  tag_name: string;
  published_at: string;
  body?: string;
  assets: ReleaseAsset[];
}

export async function GET() {
  const res = await fetch(
    `https://api.github.com/repos/${REPO}/releases/latest`,
    { next: { revalidate: 300 } },
  );

  if (!res.ok) {
    return new NextResponse("Failed to fetch release", { status: 502 });
  }

  const release: Release = await res.json();
  const version = release.tag_name.replace(/^v/, "");
  const dmg = release.assets.find((a) => a.name.endsWith(".dmg"));

  if (!dmg) {
    return new NextResponse("No DMG found in release", { status: 404 });
  }

  // Extract EdDSA signature from release body if present
  // CI appends: `<!-- sparkle-signature: sparkle:edSignature=SIG length=LEN -->`
  const sigMatch = release.body?.match(
    /sparkle:edSignature=(\S+)/,
  );
  const signatureAttr = sigMatch ? `sparkle:edSignature="${sigMatch[1]}"` : "";

  const pubDate = new Date(release.published_at).toUTCString();

  const xml = `<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
  <channel>
    <title>Scry</title>
    <link>https://github.com/${REPO}</link>
    <description>Scry updates</description>
    <language>en</language>
    <item>
      <title>Version ${version}</title>
      <pubDate>${pubDate}</pubDate>
      <sparkle:shortVersionString>${version}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>13.0</sparkle:minimumSystemVersion>
      <enclosure url="${dmg.browser_download_url}" length="${dmg.size}" type="application/octet-stream" ${signatureAttr}/>
    </item>
  </channel>
</rss>`;

  return new NextResponse(xml, {
    headers: { "Content-Type": "application/xml" },
  });
}
