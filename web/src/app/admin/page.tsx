"use client";

import { useCallback, useEffect, useState } from "react";
import Link from "next/link";
import { useAuth } from "@/lib/auth";
import { getBrowserClient } from "@/lib/supabase";
import { BOOKING_STATUS_LABEL, PAYMENT_STATUS_LABEL, type AppUser, type Booking, type Equipment, type Payment } from "@/lib/types";
import { formatDate, formatRupiah } from "@/lib/format";

type Tab = "ringkasan" | "booking" | "pembayaran" | "katalog" | "pengguna";

type BookingRow = Booking & { users?: { name: string; email: string } | null };

export default function AdminPage() {
  const { user, appUser, loading } = useAuth();
  const [tab, setTab] = useState<Tab>("ringkasan");
  const [bookings, setBookings] = useState<BookingRow[]>([]);
  const [payments, setPayments] = useState<(Payment & { booking?: { booking_code: string } | null })[]>([]);
  const [equipments, setEquipments] = useState<Equipment[]>([]);
  const [users, setUsers] = useState<AppUser[]>([]);
  const [message, setMessage] = useState("");
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);

  const load = useCallback(async () => {
    const supabase = getBrowserClient();
    const [b, p, e, u] = await Promise.all([
      supabase.from("bookings").select("*, users(name, email)").order("created_at", { ascending: false }),
      supabase.from("payments").select("*, booking:bookings(booking_code)").order("created_at", { ascending: false }),
      supabase.from("equipments").select("*").order("id"),
      supabase.from("users").select("*").order("id"),
    ]);
    if (!b.error && b.data) setBookings(b.data as BookingRow[]);
    if (!p.error && p.data) setPayments(p.data as never);
    if (!e.error && e.data) setEquipments(e.data as Equipment[]);
    if (!u.error && u.data) setUsers(u.data as AppUser[]);
  }, []);

  useEffect(() => {
    if (appUser?.role === "admin") void load();
  }, [appUser, load]);

  async function updateBooking(id: number, patch: Partial<Booking>) {
    setError("");
    setBusy(true);
    const { error: err } = await getBrowserClient().from("bookings").update(patch).eq("id", id);
    setBusy(false);
    if (err) setError(err.message);
    else {
      setMessage("Booking diperbarui.");
      await load();
    }
  }

  async function verifyPayment(id: number, status: "approved" | "rejected", reason?: string) {
    setError("");
    setBusy(true);
    const supabase = getBrowserClient();
    const patch: Record<string, unknown> = { status, verified_at: new Date().toISOString() };
    if (reason) patch.rejection_reason = reason;
    const { error: err } = await supabase.from("payments").update(patch).eq("id", id);
    setBusy(false);
    if (err) setError(err.message);
    else {
      setMessage(`Pembayaran ${status === "approved" ? "disetujui" : "ditolak"}.`);
      await load();
    }
  }

  async function updateEquipment(id: number, patch: Partial<Equipment>) {
    setError("");
    setBusy(true);
    const { error: err } = await getBrowserClient().from("equipments").update(patch).eq("id", id);
    setBusy(false);
    if (err) setError(err.message);
    else {
      setMessage("Alat diperbarui.");
      await load();
    }
  }

  async function setUserRole(id: number, role: "admin" | "customer") {
    setError("");
    setBusy(true);
    const { error: err } = await getBrowserClient().from("users").update({ role }).eq("id", id);
    setBusy(false);
    if (err) setError(err.message);
    else {
      setMessage(`Peran pengguna diubah ke ${role}.`);
      await load();
    }
  }

  if (loading) {
    return (
      <div className="wrap empty">
        <p>Memuat admin.</p>
      </div>
    );
  }

  if (!user) {
    return (
      <div className="wrap narrow">
        <h1>Login dulu.</h1>
        <Link href="/masuk" className="btn btn-primary">Masuk</Link>
      </div>
    );
  }

  if (appUser?.role !== "admin") {
    return (
      <div className="wrap narrow">
        <h1>Halaman ini khusus admin.</h1>
        <p>
          Akun kamu berperan customer. Akun admin dibuat dengan mengubah role lewat SQL:{" "}
          <code>update public.users set role = &apos;admin&apos; where email = &apos;...&apos;</code>
        </p>
        <Link href="/" className="btn btn-primary">Kembali ke Beranda</Link>
      </div>
    );
  }

  const pendingPayments = payments.filter((p) => p.status === "pending").length;
  const activeBookings = bookings.filter((b) => ["pending_payment", "pending_verification", "confirmed", "in_use"].includes(b.status)).length;
  const revenue = bookings
    .filter((b) => b.status === "completed")
    .reduce((n, b) => n + Number(b.grand_total), 0);

  return (
    <div className="wrap" style={{ paddingTop: 48, paddingBottom: 96 }}>
      <h1 style={{ fontSize: 36, fontWeight: 900, marginBottom: 8 }}>Admin.</h1>
      <p style={{ color: "var(--ink-soft)", marginBottom: 24 }}>
        Ringkasan, booking, pembayaran, katalog, dan pengguna. Semua perubahan langsung ke Supabase.
      </p>
      {message && <p className="form-ok" style={{ marginBottom: 24 }}>{message}</p>}
      {error && <p className="form-error" style={{ marginBottom: 24 }}>{error}</p>}

      <div className="admin-tabs" role="tablist" aria-label="Menu admin">
        {(["ringkasan", "booking", "pembayaran", "katalog", "pengguna"] as Tab[]).map((t) => (
          <button key={t} type="button" role="tab" className={tab === t ? "active" : ""} onClick={() => setTab(t)}>
            {t === "ringkasan" ? "Ringkasan" : t === "booking" ? "Booking" : t === "pembayaran" ? "Pembayaran" : t === "katalog" ? "Katalog" : "Pengguna"}
          </button>
        ))}
      </div>

      {tab === "ringkasan" && (
        <>
          <div className="stat-grid">
            <div className="stat"><strong>{bookings.length}</strong><span>Total booking</span></div>
            <div className="stat"><strong>{activeBookings}</strong><span>Booking aktif</span></div>
            <div className="stat"><strong>{pendingPayments}</strong><span>Pembayaran menunggu</span></div>
            <div className="stat"><strong>{formatRupiah(revenue)}</strong><span>Nilai booking selesai</span></div>
          </div>
          <p style={{ color: "var(--ink-soft)" }}>
            {equipments.filter((e) => e.is_active).length} alat aktif dari {equipments.length} alat,{" "}
            {users.length} pengguna terdaftar.
          </p>
        </>
      )}

      {tab === "booking" && (
        <div className="table-wrap">
          <table>
            <thead>
              <tr><th>Kode</th><th>Penyewa</th><th>Tanggal</th><th>Total</th><th>Status</th><th>Aksi</th></tr>
            </thead>
            <tbody>
              {bookings.map((b) => (
                <tr key={b.id}>
                  <td>{b.booking_code}</td>
                  <td>{b.users?.name ?? "-"}<br /><small>{b.users?.email ?? ""}</small></td>
                  <td>{formatDate(b.pickup_date)} s.d. {formatDate(b.return_date)}</td>
                  <td>{formatRupiah(Number(b.grand_total))}</td>
                  <td><span className={`status status-${b.status}`}>{BOOKING_STATUS_LABEL[b.status]}</span></td>
                  <td>
                    <select
                      aria-label={`Ubah status ${b.booking_code}`}
                      value={b.status}
                      disabled={busy}
                      onChange={(e) => void updateBooking(b.id, { status: e.target.value as Booking["status"] })}
                    >
                      {(Object.keys(BOOKING_STATUS_LABEL) as Booking["status"][]).map((s) => (
                        <option key={s} value={s}>{BOOKING_STATUS_LABEL[s]}</option>
                      ))}
                    </select>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {tab === "pembayaran" && (
        <div className="table-wrap">
          <table>
            <thead>
              <tr><th>Booking</th><th>Jumlah</th><th>Bank</th><th>Status</th><th>Aksi</th></tr>
            </thead>
            <tbody>
              {payments.map((p) => (
                <tr key={p.id}>
                  <td>{p.booking?.booking_code ?? `#${p.booking_id}`}</td>
                  <td>{formatRupiah(Number(p.amount))}</td>
                  <td>{p.bank_name ?? "-"} · {p.account_name ?? "-"}</td>
                  <td><span className={`status status-${p.status}`}>{PAYMENT_STATUS_LABEL[p.status]}</span></td>
                  <td>
                    {p.status === "pending" ? (
                      <span style={{ display: "flex", gap: 8 }}>
                        <button type="button" className="btn btn-primary btn-small" disabled={busy} onClick={() => void verifyPayment(p.id, "approved")}>
                          Setujui
                        </button>
                        <button
                          type="button"
                          className="btn btn-ghost btn-small"
                          disabled={busy}
                          onClick={() => {
                            const reason = window.prompt("Alasan penolakan:");
                            if (reason) void verifyPayment(p.id, "rejected", reason);
                          }}
                        >
                          Tolak
                        </button>
                      </span>
                    ) : (
                      <span>{p.rejection_reason ?? "-"}</span>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {tab === "katalog" && (
        <div className="table-wrap">
          <table>
            <thead>
              <tr><th>Alat</th><th>Harga / hari</th><th>Stok</th><th>Deposit</th><th>Aktif</th></tr>
            </thead>
            <tbody>
              {equipments.map((e) => (
                <tr key={e.id}>
                  <td>{e.name}</td>
                  <td>
                    <input
                      type="number"
                      aria-label={`Harga ${e.name}`}
                      defaultValue={Number(e.price_per_day)}
                      disabled={busy}
                      style={{ width: 120, font: "inherit", padding: 6 }}
                      onBlur={(ev) => {
                        const v = Number(ev.target.value);
                        if (v > 0 && v !== Number(e.price_per_day)) void updateEquipment(e.id, { price_per_day: v });
                      }}
                    />
                  </td>
                  <td>
                    <input
                      type="number"
                      aria-label={`Stok ${e.name}`}
                      defaultValue={e.stock}
                      disabled={busy}
                      style={{ width: 80, font: "inherit", padding: 6 }}
                      onBlur={(ev) => {
                        const v = Number(ev.target.value);
                        if (v >= 0 && v !== e.stock) void updateEquipment(e.id, { stock: v });
                      }}
                    />
                  </td>
                  <td>{formatRupiah(Number(e.deposit))}</td>
                  <td>
                    <input
                      type="checkbox"
                      aria-label={`Aktif ${e.name}`}
                      checked={e.is_active}
                      disabled={busy}
                      onChange={(ev) => void updateEquipment(e.id, { is_active: ev.target.checked })}
                    />
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          <p style={{ padding: 14, color: "var(--ink-soft)", fontSize: 14 }}>
            Ubah harga atau stok, lalu klik di luar kolom untuk menyimpan.
          </p>
        </div>
      )}

      {tab === "pengguna" && (
        <div className="table-wrap">
          <table>
            <thead>
              <tr><th>Nama</th><th>Email</th><th>Telepon</th><th>Peran</th></tr>
            </thead>
            <tbody>
              {users.map((u) => (
                <tr key={u.id}>
                  <td>{u.name}</td>
                  <td>{u.email}</td>
                  <td>{u.phone ?? "-"}</td>
                  <td>
                    <select
                      aria-label={`Peran ${u.email}`}
                      value={u.role}
                      disabled={busy}
                      onChange={(e) => void setUserRole(u.id, e.target.value as "admin" | "customer")}
                    >
                      <option value="customer">Customer</option>
                      <option value="admin">Admin</option>
                    </select>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
