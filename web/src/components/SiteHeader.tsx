"use client";

import { useEffect, useRef, useState } from "react";
import Link from "next/link";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
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
  const searchParams = useSearchParams();
  const [scrolled, setScrolled] = useState(false);
  const [menuOpen, setMenuOpen] = useState(false);
  const [query, setQuery] = useState("");
  const [categories, setCategories] = useState<Category[]>(SEED_CATEGORIES);
  const [activeCat, setActiveCat] = useState("semua");
  // Header sembunyi saat scroll ke bawah, muncul lagi saat scroll ke
  // atas (hide on scroll down, show on scroll up). Ambang 140px supaya
  // goyangan kecil tidak menyembunyikan header. Transform, bukan
  // display, jadi konten tidak lompat. Menu akun ikut tertutup saat
  // header bersembunyi.
  const [headerHidden, setHeaderHidden] = useState(false);
  const lastScrollY = useRef(0);

  useEffect(() => {
    function onScroll() {
      const y = window.scrollY;
      const last = lastScrollY.current;
      setScrolled(y > 12);
      if (y > 140 && y > last) {
        setHeaderHidden(true);
        setMenuOpen(false);
      } else if (y < last || y <= 140) {
        setHeaderHidden(false);
      }
      lastScrollY.current = y;
    }
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  // Menu akun menutup sendiri saat halaman berpindah.
  // activeCat ikut query kategori, bukan hanya pathname: pindah antar
  // kategori di /katalog tidak mengubah pathname, jadi tanpa
  // searchParams di dependensi, pill yang tersorot tidak pernah berubah.
  useEffect(() => {
    setMenuOpen(false);
    setActiveCat(searchParams.get("kategori") ?? "semua");
  }, [pathname, searchParams]);

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
    <header className={`site-header${scrolled ? " scrolled" : ""}${headerHidden ? " header-hidden" : ""}`}>
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
          <Link
            href="/keranjang"
            className="cart-link"
            aria-label={count > 0 ? `Keranjang, ${count} alat` : "Keranjang"}
          >
            <svg
              className="cart-icon"
              width="22"
              height="22"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="2"
              strokeLinecap="round"
              strokeLinejoin="round"
              aria-hidden="true"
            >
              <circle cx="9" cy="21" r="1" />
              <circle cx="20" cy="21" r="1" />
              <path d="M1 1h4l2.68 13.39a2 2 0 0 0 2 1.61h9.72a2 2 0 0 0 2-1.61L23 6H6" />
            </svg>
            <span className="cart-label">
              Keranjang{count > 0 ? ` (${count})` : ""}
            </span>
            {count > 0 && (
              <span className="cart-badge" aria-hidden="true">
                {count > 99 ? "99+" : count}
              </span>
            )}
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
              <Link href="/profil" className="btn btn-ghost header-user-name">{displayName}</Link>
              <button type="button" className="btn btn-ghost" onClick={() => void signOut()}>Keluar</button>
            </>
          )}
          {!loading && !user && (
            <>
              <Link href="/masuk" className="btn btn-primary">Masuk</Link>
              <Link href="/daftar" className="btn btn-ghost header-signup">Daftar</Link>
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
