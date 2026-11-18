"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import Image from "next/image";
import { cartSummary, useCart } from "@/lib/cart";
import { fetchCatalog, type CatalogData } from "@/lib/data";
import { formatDate, formatRupiah, rentalDays } from "@/lib/format";
import { photoForEquipment } from "@/lib/seed";

export default function CartPage() {
  const { items, startDate, endDate, setDates, setQty, removeItem } = useCart();
  const [catalog, setCatalog] = useState<CatalogData | null>(null);

  useEffect(() => {
    let alive = true;
    fetchCatalog().then((data) => {
      if (alive) setCatalog(data);
    });
    return () => {
      alive = false;
    };
  }, []);

  if (!catalog) {
    return (
      <div className="wrap empty">
        <p>Memuat keranjang.</p>
      </div>
    );
  }

  const days = rentalDays(startDate, endDate);
  const summary = cartSummary(items, catalog.equipments, days);

  if (items.length === 0) {
    return (
      <div className="wrap empty">
        <h1>Keranjang masih kosong.</h1>
        <p>Pilih tanggal sewa, lalu tambahkan alat dari katalog.</p>
        <Link href="/katalog" className="btn btn-primary">Buka Katalog</Link>
      </div>
    );
  }

  return (
    <div className="wrap cart-layout">
      <div>
        <h1 style={{ fontSize: 36, fontWeight: 900, marginBottom: 24 }}>Keranjang.</h1>
        <div className="form" style={{ marginBottom: 24, maxWidth: "none" }}>
          <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 16 }}>
            <div>
              <label htmlFor="ambil">Tanggal ambil</label>
              <input
                id="ambil"
                type="date"
                value={startDate}
                onChange={(e) => setDates(e.target.value || startDate, endDate)}
              />
            </div>
            <div>
              <label htmlFor="kembali">Tanggal kembali</label>
              <input
                id="kembali"
                type="date"
                value={endDate}
                min={startDate}
                onChange={(e) => setDates(startDate, e.target.value || endDate)}
              />
            </div>
          </div>
          <p className="hint">
            Periode {formatDate(startDate)} sampai {formatDate(endDate)}, {days} hari.
          </p>
        </div>

        {summary.lines.map((line) => (
          <div key={line.equipment.id} className="cart-item">
            <div className="cart-thumb">
              <Image src={photoForEquipment(line.equipment)} alt={line.equipment.name} fill sizes="120px" />
            </div>
            <div>
              <h3 style={{ fontSize: 20 }}>{line.equipment.name}</h3>
              <p style={{ color: "var(--ink-soft)" }}>
                {formatRupiah(Number(line.equipment.price_per_day))} / hari · Deposit{" "}
                {formatRupiah(Number(line.equipment.deposit))}
              </p>
              <div className="qty-row" style={{ marginTop: 8 }}>
                <button
                  type="button"
                  aria-label="Kurangi jumlah"
                  onClick={() => setQty(line.equipment.id, line.qty - 1)}
                >
                  −
                </button>
                <span>{line.qty}</span>
                <button
                  type="button"
                  aria-label="Tambah jumlah"
                  onClick={() => setQty(line.equipment.id, Math.min(line.equipment.stock, line.qty + 1))}
                >
                  +
                </button>
                <button
                  type="button"
                  className="btn btn-ghost btn-small"
                  onClick={() => removeItem(line.equipment.id)}
                >
                  Hapus
                </button>
              </div>
            </div>
            <div style={{ textAlign: "right" }}>
              <strong>{formatRupiah(line.rent)}</strong>
              <p style={{ color: "var(--ink-soft)", fontSize: 14 }}>+ deposit {formatRupiah(line.deposit)}</p>
            </div>
          </div>
        ))}
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
          Deposit dikembalikan setelah alat kembali dan diperiksa.
        </p>
        <Link href="/checkout" className="btn btn-primary btn-block">
          Lanjut ke Checkout
        </Link>
      </aside>
    </div>
  );
}
