"use client";

import { useCallback, useEffect, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useAuth } from "@/lib/auth";
import { getBrowserClient } from "@/lib/supabase";
import { BOOKING_STATUS_LABEL, type Booking, type Payment } from "@/lib/types";
import { formatDate, formatRupiah } from "@/lib/format";

const ACTIVE_STATUSES: Booking["status"][] = ["pending_payment", "pending_verification", "confirmed", "in_use"];

type BookingWithPayment = Booking & { payments?: Payment[] };

/**
 * Dashboard customer: sapaan nama, ringkasan pesanan aktif, aksi cepat,
 * dan pesanan terbaru. Sengaja beda dari landing: tanpa hero foto,
 * tanpa kategori dan alat populer, fokus ke pesanan milik sendiri.
 * Staf diarahkan ke /admin, pengunjung ke /masuk.
 */
export default function DashboardPage() {
  const router = useRouter();
  const { user, appUser, loading } = useAuth();
  const [bookings, setBookings] = useState<BookingWithPayment[]>([]);
  const [loaded, setLoaded] = useState(false);
  const [loadError, setLoadError] = useState("");

  const isStaff = appUser?.role === "admin" || appUser?.role === "moderator";

  const load = useCallback(async () => {
    if (!appUser) return;
    const supabase = getBrowserClient();
    // Query polos tanpa embed join: embed pernah gagal diam-diam di admin
    // dan menampilkan angka 0. Pembayaran digabung di client.
    const { data, error } = await supabase
      .from("bookings")
      .select("*")
      .eq("user_id", appUser.id)
      .order("created_at", { ascending: false });
    if (error) {
      setLoadError(error.message);
      return;
    }
    const rows = (data ?? []) as Booking[];
    if (rows.length > 0) {
      const { data: pays } = await supabase
        .from("payments")
        .select("*")
        .in(
          "booking_id",
          rows.map((b) => b.id),
        );
      const byBooking = new Map<number, Payment[]>();
      for (const p of (pays ?? []) as Payment[]) {
        const list = byBooking.get(p.booking_id) ?? [];
        list.push(p);
        byBooking.set(p.booking_id, list);
      }
      setBookings(rows.map((b) => ({ ...b, payments: byBooking.get(b.id) ?? [] })));
    } else {
      setBookings([]);
    }
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
        <p>Memuat dashboard.</p>
      </div>
    );
  }

  const active = bookings.filter((b) => ACTIVE_STATUSES.includes(b.status));
  const waitingPayment = bookings.filter((b) => b.status === "pending_payment").length;
  const completed = bookings.filter((b) => b.status === "completed");
  const spent = completed.reduce((n, b) => n + Number(b.grand_total), 0);
  const nextPickup = active
    .map((b) => b.pickup_date)
    .sort()
    .at(0);
  const recent = bookings.slice(0, 4);

  return (
    <div className="dash">
      <section className="dash-hero">
        <p className="dash-eyebrow">Dashboard customer</p>
        <h1>Halo, {appUser?.name ?? user.email?.split("@")[0] ?? "Penyewa"}.</h1>
        <p>
          {active.length > 0
            ? `Kamu punya ${active.length} pesanan aktif${nextPickup ? `, pengambilan terdekat ${formatDate(nextPickup)}` : ""}.`
            : "Belum ada pesanan aktif. Pilih alat dan mulai sewa pertamamu."}
        </p>
      </section>

      {loadError && <p className="form-error">Gagal memuat pesanan: {loadError}</p>}

      <div className="stat-grid dash-stats">
        <div className="stat">
          <strong>{active.length}</strong>
          <span>Pesanan aktif</span>
        </div>
        <div className="stat">
          <strong>{waitingPayment}</strong>
          <span>Menunggu pembayaran</span>
        </div>
        <div className="stat">
          <strong>{completed.length}</strong>
          <span>Pesanan selesai</span>
        </div>
        <div className="stat">
          <strong>{formatRupiah(spent)}</strong>
          <span>Total sewa selesai</span>
        </div>
      </div>

      <div className="dash-actions">
        <Link href="/katalog" className="btn btn-primary">
          Lanjut Sewa
        </Link>
        <Link href="/pesanan" className="btn btn-ghost">
          Unggah Bukti Bayar
        </Link>
        <Link href="/keranjang" className="btn btn-ghost">
          Lihat Keranjang
        </Link>
      </div>

      <section>
        <div className="section-head">
          <h2>Pesanan terbaru.</h2>
          <Link href="/pesanan">Lihat semua pesanan</Link>
        </div>
        {!loaded ? (
          <p style={{ color: "var(--ink-soft)" }}>Memuat pesanan.</p>
        ) : recent.length === 0 ? (
          <div className="card">
            <div className="card-body">
              <p style={{ color: "var(--ink-soft)" }}>
                Belum ada pesanan. Buka katalog, pilih alat, lalu checkout.
              </p>
              <Link href="/katalog" className="btn btn-primary">
                Buka Katalog
              </Link>
            </div>
          </div>
        ) : (
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>Kode</th>
                  <th>Tanggal</th>
                  <th>Total</th>
                  <th>Status</th>
                </tr>
              </thead>
              <tbody>
                {recent.map((b) => (
                  <tr key={b.id}>
                    <td>
                      <Link href="/pesanan">{b.booking_code}</Link>
                    </td>
                    <td>
                      {formatDate(b.pickup_date)} s.d. {formatDate(b.return_date)}
                    </td>
                    <td>{formatRupiah(Number(b.grand_total))}</td>
                    <td>
                      <span className={`status status-${b.status}`}>{BOOKING_STATUS_LABEL[b.status]}</span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>
    </div>
  );
}
