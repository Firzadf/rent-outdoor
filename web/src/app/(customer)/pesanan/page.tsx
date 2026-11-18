"use client";

import { Suspense, useCallback, useEffect, useState } from "react";
import Link from "next/link";
import { useSearchParams } from "next/navigation";
import { useAuth } from "@/lib/auth";
import { getBrowserClient } from "@/lib/supabase";
import { ProofLink } from "@/components/ProofLink";
import { BOOKING_STATUS_LABEL, PAYMENT_STATUS_LABEL, type Booking, type Payment } from "@/lib/types";
import { formatDate, formatRupiah } from "@/lib/format";

type BookingWithItems = Booking & { payments?: Payment[] };

function OrdersContent() {
  const { user, appUser, loading } = useAuth();
  const params = useSearchParams();
  const newCode = params.get("baru");
  const [bookings, setBookings] = useState<BookingWithItems[]>([]);
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState("");
  const [error, setError] = useState("");

  const load = useCallback(async () => {
    if (!appUser) return;
    const supabase = getBrowserClient();
    const { data, error: err } = await supabase
      .from("bookings")
      .select("*, booking_items(*, equipment:equipments(name)), payments(*)")
      .eq("user_id", appUser.id)
      .order("created_at", { ascending: false });
    if (!err && data) setBookings(data as unknown as BookingWithItems[]);
  }, [appUser]);

  useEffect(() => {
    void load();
  }, [load]);

  async function uploadProof(bookingId: number, file: File) {
    setError("");
    setMessage("");
    setBusy(true);
    try {
      const supabase = getBrowserClient();
      const path = `payments/${bookingId}/${Date.now()}-${file.name.replace(/[^a-zA-Z0-9._-]/g, "_")}`;
      const { error: uploadError } = await supabase.storage.from("payment-proofs").upload(path, file);
      if (uploadError) throw new Error(uploadError.message);
      const { data: payment } = await supabase
        .from("payments")
        .select("id")
        .eq("booking_id", bookingId)
        .order("created_at", { ascending: false })
        .limit(1)
        .maybeSingle();
      if (payment) {
        await supabase.from("payments").update({ payment_proof: path }).eq("id", payment.id);
      }
      await supabase.from("bookings").update({ status: "pending_verification" }).eq("id", bookingId);
      setMessage("Bukti bayar diunggah. Status pesanan berubah ke Menunggu Verifikasi.");
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : "Upload gagal.");
    } finally {
      setBusy(false);
    }
  }

  async function cancelBooking(bookingId: number) {
    setError("");
    setBusy(true);
    try {
      const supabase = getBrowserClient();
      const { error: err } = await supabase
        .from("bookings")
        .update({ status: "cancelled", cancellation_reason: "Dibatalkan penyewa" })
        .eq("id", bookingId);
      if (err) throw new Error(err.message);
      setMessage("Pesanan dibatalkan.");
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : "Gagal membatalkan.");
    } finally {
      setBusy(false);
    }
  }

  if (loading) {
    return (
      <div className="wrap empty">
        <p>Memuat pesanan.</p>
      </div>
    );
  }

  if (!user) {
    return (
      <div className="wrap narrow">
        <h1>Login dulu untuk melihat pesanan.</h1>
        <p>Pesanan terikat ke akun yang membuatnya.</p>
        <Link href="/masuk" className="btn btn-primary">Masuk</Link>
      </div>
    );
  }

  return (
    <div className="wrap" style={{ paddingTop: 48, paddingBottom: 96 }}>
      <h1 style={{ fontSize: 36, fontWeight: 900, marginBottom: 8 }}>Pesanan Saya.</h1>
      <p style={{ color: "var(--ink-soft)", marginBottom: 24 }}>
        {bookings.length} pesanan. Unggah bukti bayar untuk pesanan yang masih menunggu pembayaran.
      </p>
      {newCode && (
        <p className="form-ok" style={{ marginBottom: 24 }}>
          Pesanan {newCode} dibuat. Unggah bukti bayar di bawah.
        </p>
      )}
      {message && <p className="form-ok" style={{ marginBottom: 24 }}>{message}</p>}
      {error && <p className="form-error" style={{ marginBottom: 24 }}>{error}</p>}

      {bookings.length === 0 ? (
        <div className="empty" style={{ padding: 48 }}>
          <p>Belum ada pesanan.</p>
          <Link href="/katalog" className="btn btn-primary">Buka Katalog</Link>
        </div>
      ) : (
        bookings.map((b) => {
          const payment = b.payments?.[0];
          return (
            <article key={b.id} className="card" style={{ marginBottom: 24 }}>
              <div className="card-body">
                <div style={{ display: "flex", justifyContent: "space-between", gap: 16, flexWrap: "wrap" }}>
                  <h2 style={{ fontSize: 22 }}>{b.booking_code}</h2>
                  <span className={`status status-${b.status}`}>{BOOKING_STATUS_LABEL[b.status]}</span>
                </div>
                <p style={{ color: "var(--ink-soft)" }}>
                  {formatDate(b.pickup_date)} sampai {formatDate(b.return_date)} · {b.total_days} hari
                </p>
                <div className="table-wrap">
                  <table>
                    <thead>
                      <tr>
                        <th>Alat</th>
                        <th>Jumlah</th>
                        <th>Subtotal</th>
                      </tr>
                    </thead>
                    <tbody>
                      {(b.items ?? []).map((item) => (
                        <tr key={item.id}>
                          <td>{item.equipment?.name ?? `Alat #${item.equipment_id}`}</td>
                          <td>{item.quantity}</td>
                          <td>{formatRupiah(Number(item.subtotal))}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
                <p>
                  Sewa {formatRupiah(Number(b.subtotal))} + deposit {formatRupiah(Number(b.deposit_total))}
                  {Number(b.late_fee) > 0 ? ` + denda telat ${formatRupiah(Number(b.late_fee))}` : ""}
                  {Number(b.damage_fee) > 0 ? ` + biaya rusak ${formatRupiah(Number(b.damage_fee))}` : ""}
                  {Number(b.deposit_refund) > 0 ? `, deposit kembali ${formatRupiah(Number(b.deposit_refund))}` : ""}{" "}
                  = <strong>{formatRupiah(Number(b.grand_total))}</strong>
                </p>
                {payment && (
                  <p>
                    Pembayaran {formatRupiah(Number(payment.amount))} via {payment.bank_name ?? "-"} ·{" "}
                    <span className={`status status-${payment.status}`}>{PAYMENT_STATUS_LABEL[payment.status]}</span>
                    {payment.rejection_reason ? ` · Alasan ditolak: ${payment.rejection_reason}` : ""}
                    {payment.payment_proof && (
                      <>
                        {" · "}
                        <ProofLink path={payment.payment_proof} />
                      </>
                    )}
                  </p>
                )}
                <div style={{ display: "flex", gap: 12, flexWrap: "wrap" }}>
                  {b.status === "pending_payment" && (
                    <label className="btn btn-primary btn-small" style={{ cursor: "pointer" }}>
                      {busy ? "Mengunggah." : "Unggah Bukti Bayar"}
                      <input
                        type="file"
                        accept="image/*,.pdf"
                        hidden
                        disabled={busy}
                        onChange={(e) => {
                          const file = e.target.files?.[0];
                          if (file) void uploadProof(b.id, file);
                          e.target.value = "";
                        }}
                      />
                    </label>
                  )}
                  {(b.status === "pending_payment" || b.status === "pending_verification") && (
                    <button
                      type="button"
                      className="btn btn-ghost btn-small"
                      disabled={busy}
                      onClick={() => void cancelBooking(b.id)}
                    >
                      Batalkan Pesanan
                    </button>
                  )}
                </div>
              </div>
            </article>
          );
        })
      )}
    </div>
  );
}

export default function OrdersPage() {
  return (
    <Suspense>
      <OrdersContent />
    </Suspense>
  );
}
