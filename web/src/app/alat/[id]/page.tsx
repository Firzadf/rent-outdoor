import { notFound } from "next/navigation";
import { fetchCatalog, fetchEquipmentDetail } from "@/lib/data";
import { EquipmentPhoto } from "@/components/EquipmentPhoto";
import { EquipmentCard } from "@/components/EquipmentCard";
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
  const { categories, equipments } = await fetchCatalog();
  const categoryName = categories.find((c) => c.id === equipment.category_id)?.name ?? "";
  const related = equipments
    .filter((e) => e.category_id === equipment.category_id && e.id !== equipment.id && e.is_active)
    .slice(0, 3);

  return (
    <div className="wrap">
      <div className="detail">
        <div className="detail-media">
          <EquipmentPhoto equipment={equipment} images={images} sizes="(max-width: 900px) 100vw, 55vw" />
        </div>
        <div className="detail-info">
          <p style={{ fontWeight: 700, color: "var(--accent)", marginBottom: 8 }}>{categoryName}</p>
          <h1>{equipment.name}</h1>
          <p className="desc">{equipment.description}</p>
          <p style={{ marginBottom: 24 }}>
            {equipment.rating_avg > 0
              ? `Rating ${Number(equipment.rating_avg).toFixed(1)} dari ${equipment.total_reviews} ulasan`
              : "Belum ada ulasan"}
            {` · Disewa ${equipment.total_bookings} kali`}
          </p>
          <AddToCart equipment={equipment} />
        </div>
      </div>

      <section className="section" style={{ paddingTop: 0 }}>
        <div className="section-head">
          <h2>Ulasan penyewa.</h2>
        </div>
        {reviews.length === 0 ? (
          <p>Belum ada ulasan untuk alat ini.</p>
        ) : (
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>Penyewa</th>
                  <th>Rating</th>
                  <th>Ulasan</th>
                </tr>
              </thead>
              <tbody>
                {reviews.map((r) => (
                  <tr key={r.id}>
                    <td>{r.user_name ?? "Penyewa"}</td>
                    <td>{"★".repeat(r.rating)}</td>
                    <td>{r.comment ?? "-"}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>

      {related.length > 0 && (
        <section className="section" style={{ paddingTop: 0 }}>
          <div className="section-head">
            <h2>Alat lain di kategori {categoryName}.</h2>
          </div>
          <div className="eq-grid">
            {related.map((eq) => (
              <EquipmentCard
                key={eq.id}
                equipment={eq}
                images={images}
                categoryName={categoryName}
              />
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
