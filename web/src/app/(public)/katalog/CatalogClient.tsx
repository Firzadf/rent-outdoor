"use client";

import { useEffect, useMemo, useState } from "react";
import { usePathname, useRouter, useSearchParams } from "next/navigation";
import { EquipmentCard } from "@/components/EquipmentCard";
import { Tilt } from "@/components/Tilt";
import { rentalDays } from "@/lib/format";
import type { Category, Equipment, EquipmentImage } from "@/lib/types";

export function CatalogClient({
  categories,
  equipments,
  images,
}: {
  categories: Category[];
  equipments: Equipment[];
  images: EquipmentImage[];
}) {
  const params = useSearchParams();
  const router = useRouter();
  const pathname = usePathname();
  const initialCategory = params.get("kategori") ?? "semua";
  const start = params.get("start") ?? "";
  const end = params.get("end") ?? "";
  const days = start && end ? rentalDays(start, end) : null;

  const [query, setQuery] = useState(params.get("q") ?? "");
  const [category, setCategory] = useState(initialCategory);
  const [sort, setSort] = useState("populer");

  // State harus mengikuti URL: navigasi client-side antar kategori di
  // /katalog tidak me-remount komponen ini, jadi useState(initial)
  // saja membuat grid macet di kategori pertama yang dipilih.
  useEffect(() => {
    setCategory(params.get("kategori") ?? "semua");
    setQuery(params.get("q") ?? "");
  }, [params]);

  // Dropdown juga menulis ke URL, supaya pill aktif di header ikut
  // berubah saat kategori diganti dari halaman katalog.
  function changeCategory(value: string) {
    setCategory(value);
    const next = new URLSearchParams(params.toString());
    if (value === "semua") next.delete("kategori");
    else next.set("kategori", value);
    const qs = next.toString();
    router.push(qs ? `${pathname}?${qs}` : pathname);
  }

  const filtered = useMemo(() => {
    let list = equipments.filter((e) => e.is_active);
    if (category !== "semua") {
      list = list.filter((e) => e.category_id === Number(category));
    }
    const q = query.trim().toLowerCase();
    if (q) {
      list = list.filter(
        (e) =>
          e.name.toLowerCase().includes(q) ||
          (e.description ?? "").toLowerCase().includes(q),
      );
    }
    const sorted = [...list];
    if (sort === "termurah") sorted.sort((a, b) => Number(a.price_per_day) - Number(b.price_per_day));
    else if (sort === "termahal") sorted.sort((a, b) => Number(b.price_per_day) - Number(a.price_per_day));
    else if (sort === "rating") sorted.sort((a, b) => Number(b.rating_avg) - Number(a.rating_avg));
    else sorted.sort((a, b) => Number(b.total_bookings) - Number(a.total_bookings));
    return sorted;
  }, [equipments, query, category, sort]);

  return (
    <>
      <div className="filters" role="search">
        <div className="search">
          <label htmlFor="q">Cari alat</label>
          <input
            id="q"
            type="search"
            placeholder="Contoh: tenda, carrier, kompor"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
          />
        </div>
        <div>
          <label htmlFor="kategori">Kategori</label>
          <select id="kategori" value={category} onChange={(e) => changeCategory(e.target.value)}>
            <option value="semua">Semua kategori</option>
            {categories.map((c) => (
              <option key={c.id} value={c.id}>{c.name}</option>
            ))}
          </select>
        </div>
        <div>
          <label htmlFor="urut">Urutkan</label>
          <select id="urut" value={sort} onChange={(e) => setSort(e.target.value)}>
            <option value="populer">Paling sering disewa</option>
            <option value="termurah">Harga termurah</option>
            <option value="termahal">Harga termahal</option>
            <option value="rating">Rating tertinggi</option>
          </select>
        </div>
      </div>

      {days !== null && (
        <p style={{ marginBottom: 24 }}>
          Periode sewa {start} sampai {end}, {days} hari. Harga di kartu adalah harga per hari.
        </p>
      )}

      {filtered.length === 0 ? (
        <p>Tidak ada alat yang cocok dengan pencarian. Coba kata kunci atau kategori lain.</p>
      ) : (
        <div className="eq-grid">
          {filtered.map((eq: Equipment) => (
            <Tilt key={eq.id}>
              <EquipmentCard
                equipment={eq}
                images={images}
                categoryName={categories.find((c) => c.id === eq.category_id)?.name}
              />
            </Tilt>
          ))}
        </div>
      )}
    </>
  );
}
