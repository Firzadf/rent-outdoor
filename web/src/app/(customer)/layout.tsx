import { SiteHeader } from "@/components/SiteHeader";
import { SiteFooter } from "@/components/SiteFooter";

/**
 * Halaman customer setelah login memakai layout publik yang sama seperti
 * pengunjung (pola marketplace): header kaca + footer, tanpa sidebar
 * dan tanpa dashboard ala admin. Yang beda hanya menu akun di header.
 */
export default function CustomerLayout({ children }: { children: React.ReactNode }) {
  return (
    <>
      <SiteHeader />
      <main>{children}</main>
      <SiteFooter />
    </>
  );
}
