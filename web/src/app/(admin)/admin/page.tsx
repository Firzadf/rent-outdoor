"use client";

import { Suspense, useCallback, useEffect, useState } from "react";
import Link from "next/link";
import { useSearchParams } from "next/navigation";
import { useAuth } from "@/lib/auth";
import { getBrowserClient } from "@/lib/supabase";
import { ProofLink } from "@/components/ProofLink";
import { BOOKING_STATUS_LABEL, PAYMENT_STATUS_LABEL, type AppUser, type Booking, type Equipment, type Payment } from "@/lib/types";
import { formatDate, formatRupiah } from "@/lib/format";

type Tab = "ringkasan" | "booking" | "pembayaran" | "katalog" | "pengguna";

const TABS: Tab[] = ["ringkasan", "booking", "pembayaran", "katalog", "pengguna"];

type BookingRow = Booking & { userName?: string; userEmail?: string };

const ROLE_LABEL: Record<AppUser["role"], string> = {
  customer: "Customer",
  admin: "Admin",
  moderator: "Moderator",
};

function AdminContent() {
  const { user, appUser, loading } = useAuth();
  const params = useSearchParams();
  const [tab, setTab] = useState<Tab>("ringkasan");
  const [bookings, setBookings] = useState<BookingRow[]>([]);
  const [payments, setPayments] = useState<Payment[]>([]);
  const [equipments, setEquipments] = useState<Equipment[]>([]);
  const [users, setUsers] = useState<AppUser[]>([]);
  const [message, setMessage] = useState("");
  const [error, setError] = useState("");
  const [loadError, setLoadError] = useState("");
  const [dataLoading, setDataLoading] = useState(false);
  const [busy, setBusy] = useState(false);

  const isAdmin = appUser?.role === "admin";
  const isModerator = appUser?.role === "moderator";
  const isStaff = isAdmin || isModerator;

  // Tab mengikuti ?tab= di URL, supaya sidebar layout bisa berpindah tab.
  useEffect(() => {
    const t = params.get("tab");
    if (t && (TABS as string[]).includes(t)) setTab(t as Tab);
  }, [params]);

  const load = useCallback(async () => {
    const supabase = getBrowserClient();
    setDataLoading(true);
    setLoadError("");
    // Query POLOS tanpa embed join (dulu: bookings.select("*, users(...)")
    // dan payments.select("*, booking:bookings(...)")). Embed itu pernah
    // gagal diam-diam dan dashboard menampilkan semua counter 0 tanpa
    // pesan apa pun. Nama penyewa digabung di client dari daftar users.
    // Bila ada query yang gagal, errornya ditampilkan, bukan 0 diam-diam.
    const [b, p, e, u] = await Promise.all([
      supabase.from("bookings").select("*").order("created_at", { ascending: false }),
      supabase.from("payments").select("*").order("created_at", { ascending: false }),
      supabase.from("equipments").select("*").order("id"),
      supabase.from("users").select("*").order("id"),
    ]);
    const errs = [
      b.error ? `booking: ${b.error.message}` : "",
      p.error ? `pembayaran: ${p.error.message}` : "",
      e.error ? `katalog: ${e.error.message}` : "",
      u.error ? `pengguna: ${u.error.message}` : "",
    ].filter(Boolean);
    if (errs.length > 0) setLoadError(errs.join(" · "));
    const userById = new Map<number, AppUser>();
    if (!u.error && u.data) {
      for (const row of u.data as AppUser[]) userById.set(row.id, row);
      setUsers(u.data as AppUser[]);
    }
    if (!b.error && b.data) {
      setBookings(
        (b.data as Booking[]).map((row) => ({
          ...row,
          userName: userById.get(row.user_id)?.name,
          userEmail: userById.get(row.user_id)?.email,
        })),
      );
    }
    if (!p.error && p.data) setPayments(p.data as Payment[]);
    if (!e.error && e.data) setEquipments(e.data as Equipment[]);
    setDataLoading(false);
  }, []);

  useEffect(() => {
    if (isStaff) void load();
  }, [isStaff, load]);

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

  async function setUserRole(id: number, role: AppUser["role"]) {
    setError("");
    setBusy(true);
    const { error: err } = await getBrowserClient().from("users").update({ role }).eq("id", id);
    setBusy(false);
    if (err) setError(err.message);
    else {
      setMessage(`Peran pengguna diubah ke ${ROLE_LABEL[role]}.`);
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

  if (!isStaff) {
    return (
      <div className="wrap narrow">
        <h1>Halaman ini khusus admin dan moderator.</h1>
        <p>
          Akun kamu berperan customer. Akun admin dibuat dengan mengubah role lewat SQL:{" "}
          <code>update public.users set role = &apos;admin&apos; where email = &apos;...&apos;</code>
        </p>
        <Link href="/dashboard" className="btn btn-primary">Buka Dashboard Customer</Link>
      </div>
    );
  }

  const pendingPayments = payments.filter((p) => p.status === "pending").length;
  const activeBookings = bookings.filter((b) => ["pending_payment", "pending_verification", "confirmed", "in_use"].includes(b.status)).length;
  const revenue = bookings
    .filter((b) => b.status === "completed")
    .reduce((n, b) => n + Number(b.grand_total), 0);
  const paymentByBooking = new Map<number, Payment>();
  for (const p of payments) {
    if (!paymentByBooking.has(p.booking_id)) paymentByBooking.set(p.booking_id, p);
  }

  return (
    <div className="admin-page">
      <h1 style={{ fontSize: 36, fontWeight: 900, marginBottom: 8 }}>
        {isModerator ? "Moderator." : "Admin."}
      </h1>
      <p style={{ color: "var(--ink-soft)", marginBottom: 24 }}>
        {isModerator
          ? "Moderator boleh melihat dashboard, mengubah status booking, dan memverifikasi pembayaran. Moderator tidak boleh mengubah peran pengguna, harga, atau stok."
          : "Ringkasan, booking, pembayaran, katalog, dan pengguna. Semua perubahan langsung ke Supabase."}
      </p>
      {message && <p className="form-ok" style={{ marginBottom: 24 }}>{message}</p>}
      {error && <p className="form-error" style={{ marginBottom: 24 }}>{error}</p>}
      {dataLoading && <p style={{ color: "var(--ink-soft)", marginBottom: 24 }}>Memuat data admin.</p>}
      {loadError && (
        <p className="form-error" style={{ marginBottom: 24 }}>
          Gagal memuat sebagian data: {loadError}
        </p>
      )}

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
              <tr><th>Kode</th><th>Penyewa</th><th>Tanggal</th><th>Total</th><th>Status</th><th>Bukti</th><th>Aksi</th></tr>
            </thead>
            <tbody>
              {bookings.map((b) => {
                const proof = paymentByBooking.get(b.id)?.payment_proof ?? null;
                return (
                  <tr key={b.id}>
                    <td>{b.booking_code}</td>
                    <td>{b.userName ?? "-"}<br /><small>{b.userEmail ?? ""}</small></td>
                    <td>{formatDate(b.pickup_date)} s.d. {formatDate(b.return_date)}</td>
                    <td>{formatRupiah(Number(b.grand_total))}</td>
                    <td><span className={`status status-${b.status}`}>{BOOKING_STATUS_LABEL[b.status]}</span></td>
                    <td>{proof ? <ProofLink path={proof} /> : "-"}</td>
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
                );
              })}
            </tbody>
          </table>
        </div>
      )}

      {tab === "pembayaran" && (
        <div className="table-wrap">
          <table>
            <thead>
              <tr><th>Booking</th><th>Jumlah</th><th>Bank</th><th>Bukti</th><th>Status</th><th>Aksi</th></tr>
            </thead>
            <tbody>
              {payments.map((p) => {
                const code = bookings.find((b) => b.id === p.booking_id)?.booking_code;
                return (
                  <tr key={p.id}>
                    <td>{code ?? `#${p.booking_id}`}</td>
                    <td>{formatRupiah(Number(p.amount))}</td>
                    <td>{p.bank_name ?? "-"} · {p.account_name ?? "-"}</td>
                    <td>{p.payment_proof ? <ProofLink path={p.payment_proof} /> : "-"}</td>
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
                );
              })}
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
                    {isAdmin ? (
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
                    ) : (
                      formatRupiah(Number(e.price_per_day))
                    )}
                  </td>
                  <td>
                    {isAdmin ? (
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
                    ) : (
                      e.stock
                    )}
                  </td>
                  <td>{formatRupiah(Number(e.deposit))}</td>
                  <td>
                    {isAdmin ? (
                      <input
                        type="checkbox"
                        aria-label={`Aktif ${e.name}`}
                        checked={e.is_active}
                        disabled={busy}
                        onChange={(ev) => void updateEquipment(e.id, { is_active: ev.target.checked })}
                      />
                    ) : (
                      e.is_active ? "Aktif" : "Nonaktif"
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          <p style={{ padding: 14, color: "var(--ink-soft)", fontSize: 14 }}>
            {isAdmin
              ? "Ubah harga atau stok, lalu klik di luar kolom untuk menyimpan."
              : "Moderator hanya bisa melihat katalog, tidak bisa mengubah harga atau stok."}
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
                    {isAdmin ? (
                      <select
                        aria-label={`Peran ${u.email}`}
                        value={u.role}
                        disabled={busy}
                        onChange={(e) => void setUserRole(u.id, e.target.value as AppUser["role"])}
                      >
                        <option value="customer">Customer</option>
                        <option value="moderator">Moderator</option>
                        <option value="admin">Admin</option>
                      </select>
                    ) : (
                      ROLE_LABEL[u.role]
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          {!isAdmin && (
            <p style={{ padding: 14, color: "var(--ink-soft)", fontSize: 14 }}>
              Moderator hanya bisa melihat pengguna, tidak bisa mengubah peran.
            </p>
          )}
        </div>
      )}
    </div>
  );
}

export default function AdminPage() {
  return (
    <Suspense>
      <AdminContent />
    </Suspense>
  );
}
