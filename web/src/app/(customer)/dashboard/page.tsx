"use client";

import { useCallback, useEffect, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useAuth } from "@/lib/auth";
import { getBrowserClient } from "@/lib/supabase";
import { BOOKING_STATUS_LABEL, type Booking } from "@/lib/types";
import { formatDate, formatRupiah } from "@/lib/format";

const ACTIVE_STATUSES: Booking["status"][] = ["pending_payment", "pending_verification", "confirmed", "in_use"];

/**
 * Akun Saya: halaman akun customer dalam layout publik yang sama seperti
 * landing, bukan dashboard ala admin. Sapaan nama, tautan cepat biasa,
 * dan pesanan aktif sebagai daftar kartu pesanan biasa. Tanpa kotak
 * statistik dan tanpa tabel. Login mengarah ke sini, staf diarahkan
 * ke /admin, pengunjung ke /masuk.
 */
export default function AccountPage() {
  const router = useRouter();
  const { user, appUser, loading } = useAuth();
  const [bookings, setBookings] = useState<Booking[]>([]);
  const [loaded, setLoaded] = useState(false);
  const [loadError, setLoadError] = useState("");

  const isStaff = appUser?.role === "admin" || appUser?.role === "moderator";

  const load = useCallback(async () => {
    if (!appUser) return;
    const supabase = getBrowserClient();
    const { data, error } = await supabase
      .from("bookings")
      .select("*")
      .eq("user_id", appUser.id)
      .order("created_at", { ascending: false });
    if (error) {
      setLoadError(error.message);
      return;
    }
    setBookings((data ?? []) as Booking[]);
    setLoaded(true);
  }, [appUser]);

  useEffect(() => {
    if (loading) return;
    if (!user) {
      router.replace("/masuk");
      return;
    }
    if (isStaff) {
      router.replace("/admin");
      return;
    }
    void load();
  }, [loading, user, isStaff, load, router]);

  if (loading || !user || isStaff) {
    return (
      <div className="wrap empty">
        <p>Memuat akun saya.</p>
      </div>
    );
  }

  const name = appUser?.name ?? user.email?.split("@")[0] ?? "Penyewa";
  const active = bookings.filter((b) => ACTIVE_STATUSES.includes(b.status));

  return (
    <div className="wrap account">
      <section>
        <h1>Halo, {name}.</h1>
        <p>
          {active.length > 0
            ? `Kamu punya ${active.length} pesanan aktif.`
            : "Belum ada pesanan aktif. Pilih alat dan mulai sewa pertamamu."}
        </p>
      </section>

      {loadError && <p className="form-error">Gagal memuat pesanan: {loadError}</p>}

      <div className="account-actions">
        <Link href="/katalog" className="btn btn-primary">
          Lanjut Sewa
        </Link>
        <Link href="/pesanan" className="btn btn-ghost">
          Pesanan Saya
        </Link>
        <Link href="/keranjang" className="btn btn-ghost">
          Keranjang
        </Link>
        <Link href="/profil" className="btn btn-ghost">
          Profil
        </Link>
      </div>

      <section>
        <div className="section-head">
          <h2>Pesanan aktif.</h2>
          <Link href="/pesanan">Lihat semua pesanan</Link>
        </div>
        {!loaded ? (
          <p style={{ color: "var(--ink-soft)" }}>Memuat pesanan.</p>
        ) : active.length === 0 ? (
          <div className="card">
            <div className="card-body">
              <p style={{ color: "var(--ink-soft)" }}>
                Belum ada pesanan aktif. Buka katalog, pilih alat, lalu checkout.
              </p>
              <Link href="/katalog" className="btn btn-primary">
                Buka Katalog
              </Link>
            </div>
          </div>
        ) : (
          <div className="account-orders">
            {active.map((b) => (
              <article key={b.id} className="card">
                <div className="card-body">
                  <div className="order-head">
                    <strong>{b.booking_code}</strong>
                    <span className={`status status-${b.status}`}>{BOOKING_STATUS_LABEL[b.status]}</span>
                  </div>
                  <p>
                    {formatDate(b.pickup_date)} s.d. {formatDate(b.return_date)}
                  </p>
                  <p>
                    <strong>{formatRupiah(Number(b.grand_total))}</strong>
                  </p>
                  {b.status === "pending_payment" && (
                    <p style={{ color: "var(--ink-soft)" }}>
                      Menunggu pembayaran, unggah bukti di halaman Pesanan Saya.
                    </p>
                  )}
                  <Link href="/pesanan" className="btn btn-ghost">
                    Lihat pesanan
                  </Link>
                </div>
              </article>
            ))}
          </div>
        )}
      </section>
    </div>
  );
}
