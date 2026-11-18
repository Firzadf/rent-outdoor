"use client";

import Link from "next/link";
import { useSearchParams } from "next/navigation";
import { useAuth } from "@/lib/auth";
import { LogoMark } from "./LogoMark";

/**
 * Shell admin/moderator: sidebar gelap, jelas beda dari header kaca
 * landing dan sidebar customer. Tab admin dibaca dari ?tab= di URL.
 * Bila pengunjung bukan staf, sidebar tidak ditampilkan supaya pesan
 * "khusus admin/moderator" dari halaman tampil bersih.
 */
const TABS = [
  { tab: "ringkasan", label: "Ringkasan" },
  { tab: "booking", label: "Booking" },
  { tab: "pembayaran", label: "Pembayaran" },
  { tab: "katalog", label: "Katalog" },
  { tab: "pengguna", label: "Pengguna" },
];

export function AdminShell({ children }: { children: React.ReactNode }) {
  const { user, appUser, loading, signOut } = useAuth();
  const params = useSearchParams();
  const activeTab = params.get("tab") ?? "ringkasan";
  const isStaff = appUser?.role === "admin" || appUser?.role === "moderator";

  if (loading || !isStaff) {
    return <div className="app-main">{children}</div>;
  }

  return (
    <div className="app-shell">
      <aside className="app-sidebar" aria-label="Navigasi admin">
        <Link href="/admin" className="app-wordmark">
          <LogoMark size={30} />
          Outdoor<span>Rent</span>
        </Link>
        <p className="app-sidebar-note">
          Area {appUser?.role === "moderator" ? "moderator" : "admin"}
        </p>
        <nav className="app-nav">
          {TABS.map((item) => (
            <Link
              key={item.tab}
              href={`/admin?tab=${item.tab}`}
              className={activeTab === item.tab ? "active" : ""}
            >
              {item.label}
            </Link>
          ))}
        </nav>
        <div className="app-sidebar-foot">
          <Link href="/" className="app-side-link">
            Lihat Situs
          </Link>
          <span className="app-user">{appUser?.name ?? user?.email?.split("@")[0] ?? "Staf"}</span>
          <button type="button" className="app-side-link" onClick={() => void signOut()}>
            Keluar
          </button>
        </div>
      </aside>
      <div className="app-main">{children}</div>
    </div>
  );
}
