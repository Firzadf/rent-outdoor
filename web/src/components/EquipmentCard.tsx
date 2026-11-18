import Link from "next/link";
import { formatRupiah } from "@/lib/format";
import type { Equipment, EquipmentImage } from "@/lib/types";
import { EquipmentPhoto } from "./EquipmentPhoto";

export function EquipmentCard({
  equipment,
  images,
  categoryName,
}: {
  equipment: Equipment;
  images: EquipmentImage[];
  categoryName?: string;
}) {
  const outOfStock = equipment.stock <= 0;
  return (
    <article className="card">
      <Link href={`/alat/${equipment.id}`} className="card-media" aria-label={equipment.name}>
        <EquipmentPhoto equipment={equipment} images={images} className="card-img" />
        <span className="card-cat">{categoryName ?? ""}</span>
      </Link>
      <div className="card-body">
        <h3 className="card-title">
          <Link href={`/alat/${equipment.id}`}>{equipment.name}</Link>
        </h3>
        <p className="card-meta">
          {equipment.rating_avg > 0 ? `★ ${Number(equipment.rating_avg).toFixed(1)}` : "Belum ada rating"}
          {equipment.total_reviews > 0 ? ` · ${equipment.total_reviews} ulasan` : ""}
          {` · Stok ${equipment.stock}`}
        </p>
        <p className="card-price">
          {formatRupiah(Number(equipment.price_per_day))}
          <span className="card-per"> / hari</span>
        </p>
        <p className="card-deposit">Deposit {formatRupiah(Number(equipment.deposit))}</p>
        <Link
          href={`/alat/${equipment.id}`}
          className="btn btn-primary btn-block"
          aria-disabled={outOfStock}
        >
          {outOfStock ? "Stok Habis" : "Lihat Detail"}
        </Link>
      </div>
    </article>
  );
}
