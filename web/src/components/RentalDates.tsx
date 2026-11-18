"use client";

import { useState } from "react";
import Link from "next/link";
import { defaultRentalDates, rentalDays } from "@/lib/format";

/** Picker tanggal sewa di hero: harga berubah langsung saat tanggal diubah. */
export function RentalDates() {
  const initial = defaultRentalDates();
  const [start, setStart] = useState(initial.start);
  const [end, setEnd] = useState(initial.end);
  const days = rentalDays(start, end);

  return (
    <form
      className="date-picker"
      onSubmit={(e) => e.preventDefault()}
      aria-label="Pilih tanggal sewa"
    >
      <div>
        <label htmlFor="pickup">Tanggal ambil</label>
        <input
          id="pickup"
          type="date"
          value={start}
          min={initial.start}
          onChange={(e) => setStart(e.target.value || initial.start)}
        />
      </div>
      <div>
        <label htmlFor="return">Tanggal kembali</label>
        <input
          id="return"
          type="date"
          value={end}
          min={start}
          onChange={(e) => setEnd(e.target.value || start)}
        />
      </div>
      <div className="days">
        {days} hari
        <div>
          <Link
            className="btn btn-primary"
            href={`/katalog?start=${start}&end=${end}`}
          >
            Cari Alat
          </Link>
        </div>
      </div>
    </form>
  );
}
