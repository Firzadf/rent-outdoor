"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useAuth } from "@/lib/auth";
import { useCart } from "@/lib/cart";

export function SiteHeader() {
  const { user, appUser, loading, signOut } = useAuth();
  const { count } = useCart();
  const pathname = usePathname();

  return (
    <header className="site-header">
      <div className="wrap header-inner">
        <Link href="/" className="wordmark">
          Outdoor<span>Rent</span>
        </Link>
        <nav className="main-nav" aria-label="Navigasi utama">
          <Link href="/" className={pathname === "/" ? "active" : ""}>Beranda</Link>
          <Link href="/katalog" className={pathname.startsWith("/katalog") || pathname.startsWith("/alat") ? "active" : ""}>Katalog</Link>
          <Link href="/pesanan" className={pathname.startsWith("/pesanan") ? "active" : ""}>Pesanan Saya</Link>
          {appUser?.role === "admin" && (
            <Link href="/admin" className={pathname.startsWith("/admin") ? "active" : ""}>Admin</Link>
          )}
        </nav>
        <div className="header-actions">
          <Link href="/keranjang" className="cart-link">
            Keranjang{count > 0 ? ` (${count})` : ""}
          </Link>
          {loading ? null : user ? (
            <>
              <Link href="/profil" className="btn btn-ghost">{appUser?.name ?? user.email?.split("@")[0] ?? "Profil"}</Link>
              <button type="button" className="btn btn-ghost" onClick={() => void signOut()}>Keluar</button>
            </>
          ) : (
            <Link href="/masuk" className="btn btn-primary">Masuk</Link>
          )}
        </div>
      </div>
    </header>
  );
}
