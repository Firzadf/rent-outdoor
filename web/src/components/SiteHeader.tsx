"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { useAuth } from "@/lib/auth";
import { useCart } from "@/lib/cart";
import { getBrowserClient } from "@/lib/supabase";
import { SEED_CATEGORIES } from "@/lib/seed";
import type { Category } from "@/lib/types";
import { LogoMark } from "./LogoMark";

/**
 * Header marketplace (pola Zalora): baris pertama logo + pencarian +
 * keranjang + menu akun, baris kedua strip kategori. Sama untuk
 * pengunjung dan customer yang login, hanya menu akunnya berubah:
 * pengunjung melihat Masuk dan Daftar, customer melihat menu
 * "Halo, Nama" berisi Akun Saya, Pesanan Saya, Keranjang, Profil,
 * dan Keluar. Staf melihat menu Admin di navigasi utama.
 */
export function SiteHeader() {
  const { user, appUser, loading, signOut } = useAuth();
  const { count } = useCart();
  const pathname = usePathname();
  const router = useRouter();
  const [scrolled, setScrolled] = useState(false);
  const [menuOpen, setMenuOpen] = useState(false);
  const [query, setQuery] = useState("");
  const [categories, setCategories] = useState<Category[]>(SEED_CATEGORIES);
  const [activeCat, setActiveCat] = useState("semua");

  useEffect(() => {
    function onScroll() {
      setScrolled(window.scrollY > 12);
    }
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  // Menu akun menutup sendiri saat halaman berpindah.
  useEffect(() => {
    setMenuOpen(false);
    setActiveCat(new URLSearchParams(window.location.search).get("kategori") ?? "semua");
  }, [pathname]);

  // Strip kategori memakai data live, jatuh ke seed bila gagal.
  useEffect(() => {
    let alive = true;
    void (async () => {
      try {
        const { data, error } = await getBrowserClient()
          .from("categories")
          .select("*")
          .order("id");
        if (alive && !error && data && data.length > 0) setCategories(data as Category[]);
      } catch {
        // biarkan daftar seed
      }
    })();
    return () => {
      alive = false;
    };
  }, []);

  const isStaff = appUser?.role === "admin" || appUser?.role === "moderator";
  const isCustomer = !!user && !isStaff;
  const displayName = appUser?.name ?? user?.email?.split("@")[0] ?? "Akun saya";

  function search(e: React.FormEvent) {
    e.preventDefault();
    const q = query.trim();
    router.push(q ? `/katalog?q=${encodeURIComponent(q)}` : "/katalog");
  }

  return (
    <header className={`site-header${scrolled ? " scrolled" : ""}`}>
      <div className="wrap header-inner">
        <Link href="/" className="wordmark">
          <LogoMark size={32} />
          Outdoor<span>Rent</span>
        </Link>
        <form className="header-search" role="search" onSubmit={search}>
          <label htmlFor="cari-header" className="sr-only">Cari alat</label>
          <input
            id="cari-header"
            type="search"
            placeholder="Cari tenda, carrier, kompor."
            value={query}
            onChange={(e) => setQuery(e.target.value)}
          />
          <button type="submit" className="btn btn-primary btn-small">Cari</button>
        </form>
        <div className="header-actions">
          <Link href="/keranjang" className="cart-link">
            Keranjang{count > 0 ? ` (${count})` : ""}
          </Link>
          {isCustomer && (
            <div className="account-menu">
              <button
                type="button"
                className="btn btn-ghost account-menu-btn"
                aria-haspopup="true"
                aria-expanded={menuOpen}
                onClick={() => setMenuOpen((open) => !open)}
              >
                Halo, {displayName}
              </button>
              {menuOpen && (
                <div className="account-menu-list" role="menu">
                  <Link href="/dashboard" role="menuitem">Akun Saya</Link>
                  <Link href="/pesanan" role="menuitem">Pesanan Saya</Link>
                  <Link href="/keranjang" role="menuitem">
                    Keranjang{count > 0 ? ` (${count})` : ""}
                  </Link>
                  <Link href="/profil" role="menuitem">Profil</Link>
                  <button type="button" role="menuitem" onClick={() => void signOut()}>
                    Keluar
                  </button>
                </div>
              )}
            </div>
          )}
          {isStaff && !loading && (
            <>
              <Link href="/profil" className="btn btn-ghost">{displayName}</Link>
              <button type="button" className="btn btn-ghost" onClick={() => void signOut()}>Keluar</button>
            </>
          )}
          {!loading && !user && (
            <>
              <Link href="/masuk" className="btn btn-primary">Masuk</Link>
              <Link href="/daftar" className="btn btn-ghost">Daftar</Link>
            </>
          )}
        </div>
      </div>
      <nav className="cat-nav" aria-label="Kategori alat">
        <div className="wrap cat-nav-inner">
          <Link href="/katalog" className={pathname === "/katalog" && activeCat === "semua" ? "active" : ""}>
            Semua Alat
          </Link>
          {categories.map((c) => (
            <Link
              key={c.id}
              href={`/katalog?kategori=${c.id}`}
              className={pathname === "/katalog" && activeCat === String(c.id) ? "active" : ""}
            >
              {c.name}
            </Link>
          ))}
          {isStaff && (
            <Link href="/admin" className={pathname.startsWith("/admin") ? "active" : ""}>
              Admin
            </Link>
          )}
        </div>
      </nav>
    </header>
  );
}
