"use client";

import { useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { cartSummary, useCart } from "@/lib/cart";
import { useAuth } from "@/lib/auth";
import { fetchCatalog, type CatalogData } from "@/lib/data";
import { getBrowserClient } from "@/lib/supabase";
import { formatDate, formatRupiah, rentalDays } from "@/lib/format";

export default function CheckoutPage() {
  const router = useRouter();
  const { user, appUser, loading, profileMissing } = useAuth();
  const { items, startDate, endDate, clear } = useCart();
  const [catalog, setCatalog] = useState<CatalogData | null>(null);
  const [notes, setNotes] = useState("");
  const [bank, setBank] = useState("BCA");
  const [accountName, setAccountName] = useState("");
  const [accountNumber, setAccountNumber] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState("");

  useEffect(() => {
    let alive = true;
    fetchCatalog().then((data) => {
      if (alive) setCatalog(data);
    });
    return () => {
      alive = false;
    };
  }, []);

  const days = rentalDays(startDate, endDate);
  const summary = useMemo(
    () => (catalog ? cartSummary(items, catalog.equipments, days) : null),
    [catalog, items, days],
  );

  if (loading || !catalog) {
    return (
      <div className="wrap empty">
        <p>Memuat checkout.</p>
      </div>
    );
  }

  if (!user) {
    return (
      <div className="wrap narrow">
        <h1>Login dulu untuk checkout.</h1>
        <p>Pesanan harus terikat ke akun, supaya status dan bukti bayar bisa dilacak.</p>
        <Link href="/masuk" className="btn btn-primary">Masuk</Link>{" "}
        <Link href="/daftar" className="btn btn-ghost">Daftar Akun Baru</Link>
      </div>
    );
  }

  if (items.length === 0 || !summary) {
    return (
      <div className="wrap empty">
        <h1>Keranjang masih kosong.</h1>
        <p>Tambahkan alat dari katalog sebelum checkout.</p>
        <Link href="/katalog" className="btn btn-primary">Buka Katalog</Link>
      </div>
    );
  }

  if (catalog.isDemo) {
    return (
      <div className="wrap narrow">
        <h1>Checkout belum bisa dipakai.</h1>
        <p>
          Supabase belum terhubung, jadi pesanan tidak bisa disimpan. Isi{" "}
          <code>NEXT_PUBLIC_SUPABASE_URL</code> dan <code>NEXT_PUBLIC_SUPABASE_ANON_KEY</code> di{" "}
          <code>.env.local</code>.
        </p>
        <Link href="/keranjang" className="btn btn-ghost">Kembali ke Keranjang</Link>
      </div>
    );
  }

  if (profileMissing || !appUser) {
    return (
      <div className="wrap narrow">
        <h1>Profil akun belum terbentuk.</h1>
        <p>
          Akun login ada, tetapi baris profil di tabel users belum bisa dibuat.
          Coba muat ulang halaman ini, atau keluar lalu masuk lagi. Tanpa profil,
          pesanan tidak bisa disimpan karena booking butuh user_id.
        </p>
        <button type="button" className="btn btn-primary" onClick={() => window.location.reload()}>
          Muat Ulang
        </button>
      </div>
    );
  }

  async function submit() {
    setError("");
    if (!accountName.trim() || !accountNumber.trim()) {
      setError("Isi nama dan nomor rekening pengirim.");
      return;
    }
    setSubmitting(true);
    try {
      const supabase = getBrowserClient();
      const code = `OR-${new Date().toISOString().slice(0, 10).replaceAll("-", "")}-${Math.floor(1000 + Math.random() * 9000)}`;
      const { data: booking, error: bookingError } = await supabase
        .from("bookings")
        .insert({
          user_id: appUser!.id,
          booking_code: code,
          pickup_date: startDate,
          return_date: endDate,
          total_days: days,
          subtotal: summary!.subtotal,
          deposit_total: summary!.depositTotal,
          grand_total: summary!.grandTotal,
          status: "pending_payment",
          notes: notes.trim() || null,
        })
        .select()
        .single();
      if (bookingError || !booking) throw new Error(bookingError?.message ?? "Gagal membuat booking.");

      const itemsPayload = summary!.lines.map((l) => ({
        booking_id: booking.id,
        equipment_id: l.equipment.id,
        quantity: l.qty,
        price_per_day: l.equipment.price_per_day,
        subtotal: l.rent,
      }));
      const { error: itemsError } = await supabase.from("booking_items").insert(itemsPayload);
      if (itemsError) throw new Error(itemsError.message);

      const { error: paymentError } = await supabase.from("payments").insert({
        booking_id: booking.id,
        amount: summary!.grandTotal,
        bank_name: bank,
        account_name: accountName.trim(),
        account_number: accountNumber.trim(),
        status: "pending",
      });
      if (paymentError) throw new Error(paymentError.message);

      clear();
      router.push(`/pesanan?baru=${code}`);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Checkout gagal, coba lagi.");
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <div className="wrap cart-layout">
      <div>
        <h1 style={{ fontSize: 36, fontWeight: 900, marginBottom: 8 }}>Checkout.</h1>
        <p style={{ color: "var(--ink-soft)", marginBottom: 24 }}>
          {formatDate(startDate)} sampai {formatDate(endDate)}, {days} hari · {summary.lines.length} jenis alat
        </p>
        <div className="table-wrap" style={{ marginBottom: 24 }}>
          <table>
            <thead>
              <tr>
                <th>Alat</th>
                <th>Jumlah</th>
                <th>Sewa</th>
                <th>Deposit</th>
              </tr>
            </thead>
            <tbody>
              {summary.lines.map((l) => (
                <tr key={l.equipment.id}>
                  <td>{l.equipment.name}</td>
                  <td>{l.qty}</td>
                  <td>{formatRupiah(l.rent)}</td>
                  <td>{formatRupiah(l.deposit)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        <div className="form" style={{ maxWidth: "none" }}>
          <div>
            <label htmlFor="bank">Bank pengirim</label>
            <select id="bank" value={bank} onChange={(e) => setBank(e.target.value)}>
              <option>BCA</option>
              <option>BRI</option>
              <option>Mandiri</option>
              <option>BNI</option>
            </select>
          </div>
          <div>
            <label htmlFor="nama-rek">Nama pemilik rekening</label>
            <input id="nama-rek" value={accountName} onChange={(e) => setAccountName(e.target.value)} />
          </div>
          <div>
            <label htmlFor="no-rek">Nomor rekening</label>
            <input id="no-rek" value={accountNumber} onChange={(e) => setAccountNumber(e.target.value)} />
          </div>
          <div>
            <label htmlFor="catatan">Catatan untuk admin</label>
            <textarea id="catatan" rows={3} value={notes} onChange={(e) => setNotes(e.target.value)} />
          </div>
          {error && <p className="form-error">{error}</p>}
        </div>
      </div>

      <aside className="summary" aria-label="Ringkasan biaya">
        <h2>Ringkasan biaya.</h2>
        <div className="price-row">
          <span>Sewa {days} hari</span>
          <span>{formatRupiah(summary.subtotal)}</span>
        </div>
        <div className="price-row">
          <span>Deposit</span>
          <span>{formatRupiah(summary.depositTotal)}</span>
        </div>
        <div className="price-row total">
          <span>Total bayar</span>
          <span>{formatRupiah(summary.grandTotal)}</span>
        </div>
        <p style={{ color: "var(--ink-soft)", fontSize: 15, margin: "12px 0 20px" }}>
          Setelah pesanan dibuat, unggah bukti transfer di halaman Pesanan Saya.
          Status berubah ke Menunggu Verifikasi setelah bukti diunggah.
        </p>
        <button type="button" className="btn btn-primary btn-block" disabled={submitting} onClick={() => void submit()}>
          {submitting ? "Membuat pesanan." : "Buat Pesanan"}
        </button>
      </aside>
    </div>
  );
}
