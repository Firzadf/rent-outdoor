import { Suspense } from "react";
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
      {/* Suspense wajib: SiteHeader memakai useSearchParams untuk
          menyorot pill kategori aktif. */}
      <Suspense>
        <SiteHeader />
      </Suspense>
      <main>{children}</main>
      <SiteFooter />
    </>
  );
}
