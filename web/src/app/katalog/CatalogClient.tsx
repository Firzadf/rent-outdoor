"use client";

import { useMemo, useState } from "react";
import { useSearchParams } from "next/navigation";
import { EquipmentCard } from "@/components/EquipmentCard";
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
  const initialCategory = params.get("kategori") ?? "semua";
  const start = params.get("start") ?? "";
  const end = params.get("end") ?? "";
  const days = start && end ? rentalDays(start, end) : null;

  const [query, setQuery] = useState("");
  const [category, setCategory] = useState(initialCategory);
  const [sort, setSort] = useState("populer");

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
          <select id="kategori" value={category} onChange={(e) => setCategory(e.target.value)}>
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
            <EquipmentCard
              key={eq.id}
              equipment={eq}
              images={images}
              categoryName={categories.find((c) => c.id === eq.category_id)?.name}
            />
          ))}
        </div>
      )}
    </>
  );
}
