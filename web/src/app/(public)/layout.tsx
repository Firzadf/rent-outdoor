import { Suspense } from "react";
import { SiteHeader } from "@/components/SiteHeader";
import { SiteFooter } from "@/components/SiteFooter";

/** Pengalaman publik: landing, katalog, detail alat, masuk, daftar. */
export default function PublicLayout({ children }: { children: React.ReactNode }) {
  return (
    <>
      {/* Suspense wajib: SiteHeader memakai useSearchParams untuk
          menyorot pill kategori aktif, dan Next tidak mengizinkan
          useSearchParams di luar Suspense saat prerender. */}
      <Suspense>
        <SiteHeader />
      </Suspense>
      <main>{children}</main>
      <SiteFooter />
    </>
  );
}
