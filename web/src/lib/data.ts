import { getServerClient, isSupabaseConfigured, publicStorageUrl } from "./supabase";
import { SEED_CATEGORIES, SEED_EQUIPMENTS, SEED_IMAGES, SEED_REVIEWS, photoForEquipment } from "./seed";
import type { Category, Equipment, EquipmentImage, Review } from "./types";

export type CatalogData = {
  categories: Category[];
  equipments: Equipment[];
  images: EquipmentImage[];
  /** true bila data berasal dari seed contoh, bukan Supabase live. */
  isDemo: boolean;
};

export async function fetchCatalog(): Promise<CatalogData> {
  if (!isSupabaseConfigured()) {
    return { categories: SEED_CATEGORIES, equipments: SEED_EQUIPMENTS, images: SEED_IMAGES, isDemo: true };
  }
  try {
    const supabase = getServerClient();
    const [cats, eqs, imgs] = await Promise.all([
      supabase.from("categories").select("*").order("id"),
      supabase.from("equipments").select("*").order("id"),
      supabase.from("equipment_images").select("*").order("sort_order"),
    ]);
    if (cats.error || eqs.error || imgs.error || !eqs.data?.length) {
      return { categories: SEED_CATEGORIES, equipments: SEED_EQUIPMENTS, images: SEED_IMAGES, isDemo: true };
    }
    return {
      categories: (cats.data ?? []) as Category[],
      equipments: (eqs.data ?? []) as Equipment[],
      images: (imgs.data ?? []) as EquipmentImage[],
      isDemo: false,
    };
  } catch {
    return { categories: SEED_CATEGORIES, equipments: SEED_EQUIPMENTS, images: SEED_IMAGES, isDemo: true };
  }
}

export async function fetchEquipmentDetail(id: number): Promise<{
  equipment: Equipment | null;
  images: EquipmentImage[];
  reviews: Review[];
  isDemo: boolean;
}> {
  const catalog = await fetchCatalog();
  const equipment = catalog.equipments.find((e) => e.id === id) ?? null;
  const images = catalog.images.filter((i) => i.equipment_id === id);
  let reviews: Review[] = SEED_REVIEWS.filter((r) => r.equipment_id === id);
  if (!catalog.isDemo) {
    try {
      const supabase = getServerClient();
      const { data, error } = await supabase
        .from("reviews")
        .select("*, users(name)")
        .eq("equipment_id", id)
        .order("created_at", { ascending: false });
      if (!error && data) {
        reviews = data.map((r: Record<string, unknown>) => ({
          id: r.id as number,
          booking_id: r.booking_id as number,
          user_id: r.user_id as number,
          equipment_id: r.equipment_id as number,
          rating: r.rating as number,
          comment: (r.comment as string | null) ?? null,
          created_at: r.created_at as string,
          user_name: (r.users as { name?: string } | null)?.name ?? "Penyewa",
        }));
      }
    } catch {
      // biarkan review seed
    }
  }
  return { equipment, images, reviews, isDemo: catalog.isDemo };
}

/** Foto utama alat: URL bucket bila ada, kalau gagal muat jatuh ke foto referensi. */
export function equipmentPhotoUrl(equipment: Equipment, images: EquipmentImage[]): string {
  const primary = images.find((i) => i.equipment_id === equipment.id && i.is_primary) ??
    images.find((i) => i.equipment_id === equipment.id);
  if (primary && primary.image_url.startsWith("uploads/")) {
    return publicStorageUrl("equipment-images", primary.image_url);
  }
  if (primary && primary.image_url.startsWith("http")) {
    return primary.image_url;
  }
  return photoForEquipment(equipment);
}
