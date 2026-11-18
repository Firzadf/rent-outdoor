"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useAuth } from "@/lib/auth";
import { useCart } from "@/lib/cart";

/**
 * Shell customer: sidebar hijau forest, jelas beda dari header kaca
 * landing. Dipakai dashboard, pesanan, keranjang, checkout, dan profil.
 * Di layar kecil sidebar menjadi baris navigasi horizontal di atas.
 */
const NAV = [
  { href: "/dashboard", label: "Dashboard" },
  { href: "/pesanan", label: "Pesanan Saya" },
  { href: "/keranjang", label: "Keranjang" },
  { href: "/profil", label: "Profil" },
];

export function CustomerShell({ children }: { children: React.ReactNode }) {
  const { user, appUser, loading, signOut } = useAuth();
  const { count } = useCart();
  const pathname = usePathname();

  return (
    <div className="app-shell">
      <aside className="app-sidebar" aria-label="Navigasi customer">
        <Link href="/dashboard" className="app-wordmark">
          Outdoor<span>Rent</span>
        </Link>
        <p className="app-sidebar-note">Area customer</p>
        <nav className="app-nav">
          {NAV.map((item) => (
            <Link
              key={item.href}
              href={item.href}
              className={pathname === item.href || pathname.startsWith(`${item.href}/`) ? "active" : ""}
            >
              {item.label}
              {item.href === "/keranjang" && count > 0 ? ` (${count})` : ""}
            </Link>
          ))}
        </nav>
        <div className="app-sidebar-foot">
          <Link href="/katalog" className="app-side-link">
            Lihat Katalog
          </Link>
          <Link href="/" className="app-side-link">
            Kembali ke Beranda
          </Link>
          {!loading &&
            (user ? (
              <>
                <span className="app-user">{appUser?.name ?? user.email?.split("@")[0] ?? "Akun saya"}</span>
                <button type="button" className="app-side-link" onClick={() => void signOut()}>
                  Keluar
                </button>
              </>
            ) : (
              <Link href="/masuk" className="app-side-link strong">
                Masuk
              </Link>
            ))}
        </div>
      </aside>
      <div className="app-main">{children}</div>
    </div>
  );
}
