import type { Metadata, Viewport } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "ZAXEL-Learning — ビジネススキルが身につくクイズ",
  description:
    "現場で鍛えたコミュニケーション・思考法・組織論を、スマホでサクッと学べるクイズに。",
  applicationName: "ZAXEL-Learning",
  manifest: "/manifest.webmanifest",
  appleWebApp: {
    capable: true,
    title: "ZAXEL-Learning",
    statusBarStyle: "black-translucent",
  },
};

export const viewport: Viewport = {
  themeColor: "#0b0f1a",
  width: "device-width",
  initialScale: 1,
  maximumScale: 1,
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="ja">
      <body className="antialiased no-tap-highlight">{children}</body>
    </html>
  );
}
