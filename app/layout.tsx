import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Gaia",
  description: "Gaia authentication and controller bridge",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
