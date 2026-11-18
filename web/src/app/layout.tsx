import type { Metadata } from "next";
import { Archivo, Fraunces } from "next/font/google";
import { AuthProvider } from "@/lib/auth";
import { CartProvider } from "@/lib/cart";
import { IntroLoader } from "@/components/IntroLoader";
import "./globals.css";

/**
 * Tipografi (disiplin Typewolf): Fraunces sebagai display serif
 * editorial untuk h1 dan h2, Archivo sebagai grotesque bersih untuk
 * body dan antarmuka. Dua typeface, token di :root, tanpa dependensi
 * di luar next/font.
 */
const archivo = Archivo({
  subsets: ["latin"],
  weight: ["400", "500", "600", "700", "800", "900"],
  display: "swap",
  variable: "--font-archivo",
});

const fraunces = Fraunces({
  subsets: ["latin"],
  weight: ["600", "900"],
  display: "swap",
  variable: "--font-fraunces",
});

export const metadata: Metadata = {
  title: "OutdoorRent, Sewa Alat Outdoor",
  description:
    "Sewa tenda, carrier, sleeping bag, dan peralatan hiking. Harga per hari, deposit dikembalikan setelah alat kembali.",
  icons: {
    icon: [
      { url: "/favicon.ico", sizes: "16x16 32x32 48x48" },
      { url: "/icon-192.png", sizes: "192x192", type: "image/png" },
      { url: "/icon-512.png", sizes: "512x512", type: "image/png" },
    ],
    apple: [{ url: "/apple-touch-icon.png", sizes: "180x180", type: "image/png" }],
  },
};

/**
 * Layout akar hanya menyediakan font, provider, dan CSS.
 * Header dan footer beda per pengalaman, jadi dipasang di layout
 * route group masing-masing: (public) dan (customer) memakai
 * SiteHeader + SiteFooter yang sama (pola marketplace), (admin)
 * memakai AdminShell dengan sidebar gelap.
 */
export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="id">
      <body className={`${archivo.variable} ${fraunces.variable}`}>
        <IntroLoader />
        <AuthProvider>
          <CartProvider>{children}</CartProvider>
        </AuthProvider>
      </body>
    </html>
  );
}
