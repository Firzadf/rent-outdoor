import { Suspense } from "react";
import { fetchCatalog } from "@/lib/data";
import { CatalogClient } from "./CatalogClient";

export default async function KatalogPage() {
  const { categories, equipments, images, isDemo } = await fetchCatalog();
  return (
    <div className="wrap section reveal">
      <div className="section-head">
        <h2>Katalog alat.</h2>
        <p>
          {equipments.filter((e) => e.is_active).length} alat aktif. Harga per hari,
          deposit dibayar bersama sewa dan dikembalikan setelah alat kembali.
        </p>
      </div>
      {isDemo && (
        <p className="form-error" style={{ marginBottom: 24 }}>
          Mode contoh: Supabase belum terhubung, data yang tampil adalah data seed.
        </p>
      )}
      <Suspense>
        <CatalogClient categories={categories} equipments={equipments} images={images} />
      </Suspense>
    </div>
  );
}
