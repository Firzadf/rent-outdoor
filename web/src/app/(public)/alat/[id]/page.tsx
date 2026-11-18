import Link from "next/link";
import { notFound } from "next/navigation";
import { fetchCatalog, fetchEquipmentDetail } from "@/lib/data";
import { EquipmentPhoto } from "@/components/EquipmentPhoto";
import { EquipmentCard } from "@/components/EquipmentCard";
import { Tilt } from "@/components/Tilt";
import { formatRupiah } from "@/lib/format";
import { AddToCart } from "./AddToCart";

export async function generateStaticParams() {
  const { equipments } = await fetchCatalog();
  return equipments.map((e) => ({ id: String(e.id) }));
}

export default async function EquipmentDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const equipmentId = Number(id);
  if (!Number.isInteger(equipmentId)) notFound();
  const { equipment, images, reviews } = await fetchEquipmentDetail(equipmentId);
  if (!equipment) notFound();
  // images di sini adalah SEMUA gambar katalog, dipakai kartu alat terkait
  // supaya tiap kartu memakai gambarnya sendiri (dulu: images alat ini).
  const { categories, equipments, images: allImages } = await fetchCatalog();
  const categoryName = categories.find((c) => c.id === equipment.category_id)?.name ?? "";
  const related = equipments
    .filter((e) => e.category_id === equipment.category_id && e.id !== equipment.id && e.is_active)
    .slice(0, 3);

  return (
    <div className="wrap">
      <nav className="crumb" aria-label="Breadcrumb">
        <Link href="/">Beranda</Link>
        <span aria-hidden="true">/</span>
        <Link href="/katalog">Katalog</Link>
        <span aria-hidden="true">/</span>
        <span aria-current="page">{equipment.name}</span>
      </nav>

      {/*
        Detail dua kolom (revisi 18 Nov 2026): galeri kiri sekitar 55
        persen dengan rasio 4/3 yang dibatasi, info kanan di atas lipatan.
        Foto tidak lagi di dalam Tilt: tilt membuat media meregang setinggi
        kolom info yang panjang, sehingga foto memenuhi seluruh viewport.
      */}
      <div className="detail">
        <div className="detail-media">
          <EquipmentPhoto equipment={equipment} images={images} sizes="(max-width: 900px) 100vw, 55vw" />
        </div>
        <div className="detail-info">
          <p style={{ fontWeight: 700, color: "var(--accent)", marginBottom: 8 }}>{categoryName}</p>
          <h1>{equipment.name}</h1>
          <p style={{ marginBottom: 16 }}>
            {equipment.rating_avg > 0
              ? `★ ${Number(equipment.rating_avg).toFixed(1)} dari ${equipment.total_reviews} ulasan`
              : "Belum ada ulasan"}
            {` · Disewa ${equipment.total_bookings} kali`}
          </p>
          <p className="desc">{equipment.description}</p>
          <AddToCart equipment={equipment} />
        </div>
      </div>

      <section className="section reveal" style={{ paddingTop: 0 }}>
        <div className="section-head">
          <h2>Keterangan sewa.</h2>
        </div>
        <div className="steps">
          <div className="step">
            <h3>Deposit kembali utuh</h3>
            <p>
              Deposit dibayar bersama sewa dan dikembalikan setelah alat
              kembali dalam kondisi baik dan diperiksa.
            </p>
          </div>
          <div className="step">
            <h3>Harga dihitung per hari</h3>
            <p>
              Sewa dihitung dari harga per hari dikali jumlah hari, dari
              tanggal ambil sampai tanggal kembali yang dipilih.
            </p>
          </div>
          <div className="step">
            <h3>Ambil dan kembali</h3>
            <p>
              Ambil alat pada tanggal yang dipilih, pakai, lalu kembalikan
              tepat waktu pada tanggal kembali.
            </p>
          </div>
        </div>
      </section>

      <section className="section reveal" style={{ paddingTop: 0 }}>
        <div className="section-head">
          <h2>Ulasan penyewa.</h2>
        </div>
        {reviews.length === 0 ? (
          <p>Belum ada ulasan untuk alat ini.</p>
        ) : (
          <div className="review-grid">
            {reviews.map((r) => (
              <article key={r.id} className="review-card">
                <strong>{r.user_name ?? "Penyewa"}</strong>
                <span className="stars" aria-label={`Rating ${r.rating} dari 5`}>
                  {"★".repeat(r.rating)}
                  {"☆".repeat(Math.max(0, 5 - r.rating))}
                </span>
                <p>{r.comment ?? "-"}</p>
              </article>
            ))}
          </div>
        )}
      </section>

      {related.length > 0 && (
        <section className="section reveal" style={{ paddingTop: 0 }}>
          <div className="section-head">
            <h2>Alat lain di kategori {categoryName}.</h2>
          </div>
          <div className="eq-grid">
            {related.map((eq) => (
              <Tilt key={eq.id}>
                <EquipmentCard
                  equipment={eq}
                  images={allImages}
                  categoryName={categoryName}
                />
              </Tilt>
            ))}
          </div>
          <p style={{ marginTop: 16, color: "var(--ink-soft)", fontSize: 15 }}>
            Harga di atas adalah harga per hari. Deposit {formatRupiah(Number(equipment.deposit))} dibayar
            bersama sewa dan dikembalikan setelah alat kembali.
          </p>
        </section>
      )}
    </div>
  );
}
