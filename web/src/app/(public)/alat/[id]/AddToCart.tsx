"use client";

import { useState } from "react";
import Link from "next/link";
import { useCart } from "@/lib/cart";
import { formatRupiah, rentalDays } from "@/lib/format";
import type { Equipment } from "@/lib/types";

export function AddToCart({ equipment }: { equipment: Equipment }) {
  const { addItem, startDate, endDate, setDates } = useCart();
  const [qty, setQty] = useState(1);
  const [added, setAdded] = useState(false);
  const days = rentalDays(startDate, endDate);
  const rent = Number(equipment.price_per_day) * qty * days;
  const deposit = Number(equipment.deposit) * qty;

  return (
    <div className="price-block">
      <div className="price-row">
        <span>Harga per hari</span>
        <strong>{formatRupiah(Number(equipment.price_per_day))}</strong>
      </div>
      <div className="price-row">
        <span>Deposit per unit</span>
        <span>{formatRupiah(Number(equipment.deposit))}</span>
      </div>
      <div className="price-row">
        <span>Stok tersedia</span>
        <span>{equipment.stock} unit</span>
      </div>
      <div>
        <label htmlFor="tgl-ambil" style={{ fontWeight: 700, display: "block", marginBottom: 6 }}>
          Tanggal ambil
        </label>
        <input
          id="tgl-ambil"
          type="date"
          value={startDate}
          onChange={(e) => setDates(e.target.value || startDate, endDate)}
          style={{ width: "100%", font: "inherit", padding: 12, border: "1px solid var(--line)", background: "var(--ground)", color: "var(--ink)" }}
        />
      </div>
      <div>
        <label htmlFor="tgl-kembali" style={{ fontWeight: 700, display: "block", marginBottom: 6 }}>
          Tanggal kembali
        </label>
        <input
          id="tgl-kembali"
          type="date"
          value={endDate}
          min={startDate}
          onChange={(e) => setDates(startDate, e.target.value || endDate)}
          style={{ width: "100%", font: "inherit", padding: 12, border: "1px solid var(--line)", background: "var(--ground)", color: "var(--ink)" }}
        />
      </div>
      <div className="qty-row">
        <span>Jumlah</span>
        <button type="button" aria-label="Kurangi jumlah" onClick={() => setQty((q) => Math.max(1, q - 1))}>−</button>
        <span>{qty}</span>
        <button
          type="button"
          aria-label="Tambah jumlah"
          onClick={() => setQty((q) => Math.min(equipment.stock, q + 1))}
        >
          +
        </button>
      </div>
      <div className="price-row">
        <span>Sewa {days} hari × {qty} unit</span>
        <strong>{formatRupiah(rent)}</strong>
      </div>
      <div className="price-row">
        <span>Deposit</span>
        <span>{formatRupiah(deposit)}</span>
      </div>
      <div className="price-row total">
        <span>Total bayar</span>
        <strong>{formatRupiah(rent + deposit)}</strong>
      </div>
      {equipment.stock <= 0 ? (
        <p className="form-error">Stok alat ini sedang habis.</p>
      ) : (
        <button
          type="button"
          className="btn btn-primary btn-block"
          onClick={() => {
            addItem(equipment.id, qty);
            setAdded(true);
          }}
        >
          Tambah ke Keranjang
        </button>
      )}
      {added && (
        <p className="form-ok">
          Ditambahkan ke keranjang. <Link href="/keranjang">Lihat keranjang</Link>
        </p>
      )}
    </div>
  );
}
