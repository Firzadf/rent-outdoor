"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { useAuth } from "@/lib/auth";
import { useCart } from "@/lib/cart";

/**
 * Header publik (landing, katalog, detail alat, masuk, daftar).
 * Navigasi menyesuaikan peran, tidak ada menu ke halaman yang tidak
 * boleh diakses peran itu:
 * - pengunjung: Beranda, Katalog, Masuk, Daftar.
 * - customer: Beranda, Katalog, Dashboard, Pesanan Saya, Keranjang, Profil.
 * - admin/moderator: Beranda, Katalog, Admin, Profil.
 */
export function SiteHeader() {
  const { user, appUser, loading, signOut } = useAuth();
  const { count } = useCart();
  const pathname = usePathname();
  const [scrolled, setScrolled] = useState(false);

  useEffect(() => {
    function onScroll() {
      setScrolled(window.scrollY > 12);
    }
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  const isStaff = appUser?.role === "admin" || appUser?.role === "moderator";
  const isCustomer = !!user && !isStaff;

  return (
    <header className={`site-header${scrolled ? " scrolled" : ""}`}>
      <div className="wrap header-inner">
        <Link href="/" className="wordmark">
          Outdoor<span>Rent</span>
        </Link>
        <nav className="main-nav" aria-label="Navigasi utama">
          <Link href="/" className={pathname === "/" ? "active" : ""}>Beranda</Link>
          <Link href="/katalog" className={pathname.startsWith("/katalog") || pathname.startsWith("/alat") ? "active" : ""}>Katalog</Link>
          {isCustomer && (
            <>
              <Link href="/dashboard" className={pathname.startsWith("/dashboard") ? "active" : ""}>Dashboard</Link>
              <Link href="/pesanan" className={pathname.startsWith("/pesanan") ? "active" : ""}>Pesanan Saya</Link>
            </>
          )}
          {isStaff && (
            <Link href="/admin" className={pathname.startsWith("/admin") ? "active" : ""}>Admin</Link>
          )}
        </nav>
        <div className="header-actions">
          {isCustomer && (
            <Link href="/keranjang" className="cart-link">
              Keranjang{count > 0 ? ` (${count})` : ""}
            </Link>
          )}
          {loading ? null : user ? (
            <>
              <Link href="/profil" className="btn btn-ghost">{appUser?.name ?? user.email?.split("@")[0] ?? "Profil"}</Link>
              <button type="button" className="btn btn-ghost" onClick={() => void signOut()}>Keluar</button>
            </>
          ) : (
            <>
              <Link href="/masuk" className="btn btn-primary">Masuk</Link>
              <Link href="/daftar" className="btn btn-ghost">Daftar</Link>
            </>
          )}
        </div>
      </div>
    </header>
  );
}
