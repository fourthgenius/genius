import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "GenieUs: electronic music events in India",
  description:
    "Discover electronic music shows in Delhi NCR, Mumbai, Bangalore, Goa, Pune and Hyderabad. Free, no tickets sold here.",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className="dark">
      <body>{children}</body>
    </html>
  );
}
