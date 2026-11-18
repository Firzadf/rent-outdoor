import type { Metadata } from "next";
import { Archivo } from "next/font/google";
import { AuthProvider } from "@/lib/auth";
import { CartProvider } from "@/lib/cart";
import { SiteHeader } from "@/components/SiteHeader";
import { SiteFooter } from "@/components/SiteFooter";
import "./globals.css";

const archivo = Archivo({
  subsets: ["latin"],
  weight: ["400", "500", "600", "700", "800", "900"],
  display: "swap",
});

export const metadata: Metadata = {
  title: "OutdoorRent, Sewa Alat Outdoor",
  description:
    "Sewa tenda, carrier, sleeping bag, dan peralatan hiking. Harga per hari, deposit dikembalikan setelah alat kembali.",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="id">
      <body className={archivo.className}>
        <AuthProvider>
          <CartProvider>
            <SiteHeader />
            <main>{children}</main>
            <SiteFooter />
          </CartProvider>
        </AuthProvider>
      </body>
    </html>
  );
}
