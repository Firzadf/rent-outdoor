import type { Category, Equipment, EquipmentImage, Review } from "./types";

/**
 * Data contoh persis dari seed migrasi 20261118000000_outdoorrent_postgres.sql.
 * Dipakai HANYA bila Supabase belum terkonfigurasi atau tidak bisa dihubungi,
 * supaya halaman tetap bisa dibuka dan diverifikasi. Bila env Supabase terisi,
 * data live yang dipakai, bukan data ini.
 */

export const SEED_CATEGORIES: Category[] = [
  { id: 1, name: "Tenda", description: "Berbagai jenis tenda untuk camping dan outdoor", icon: "tent" },
  { id: 2, name: "Carrier", description: "Tas carrier dan ransel untuk mendaki gunung", icon: "backpack" },
  { id: 3, name: "Sleeping Bag", description: "Sleeping bag untuk tidur nyaman di alam", icon: "sleeping-bag" },
  { id: 4, name: "Peralatan Masak", description: "Kompor, nesting, dan peralatan masak outdoor", icon: "cooking" },
  { id: 5, name: "Perlengkapan Hiking", description: "Trekking pole, headlamp, dan aksesoris hiking", icon: "hiking" },
];

export const SEED_EQUIPMENTS: Equipment[] = [
  { id: 1, category_id: 1, name: "Tenda Kapasitas 4 Orang", description: "Tenda dome waterproof untuk 4 orang, mudah dipasang dan kokoh. Cocok untuk camping keluarga atau grup kecil.", price_per_day: 75000, stock: 10, deposit: 300000, rating_avg: 5, total_reviews: 1, total_bookings: 2, is_active: true },
  { id: 2, category_id: 1, name: "Tenda Ultralight 2 Orang", description: "Tenda ringan hanya 1.5kg, ideal untuk pendakian. Material berkualitas tahan angin dan hujan.", price_per_day: 60000, stock: 8, deposit: 250000, rating_avg: 0, total_reviews: 0, total_bookings: 0, is_active: true },
  { id: 3, category_id: 2, name: "Carrier 60L Eiger", description: "Carrier 60 liter dengan frame internal, cocok untuk pendakian 2-3 hari. Sistem ventilasi punggung yang baik.", price_per_day: 50000, stock: 12, deposit: 400000, rating_avg: 0, total_reviews: 0, total_bookings: 0, is_active: true },
  { id: 4, category_id: 2, name: "Carrier 80L Professional", description: "Carrier besar 80 liter untuk pendakian jarak jauh. Dilengkapi rain cover dan banyak kompartemen.", price_per_day: 65000, stock: 6, deposit: 500000, rating_avg: 0, total_reviews: 0, total_bookings: 0, is_active: true },
  { id: 5, category_id: 3, name: "Sleeping Bag Suhu -5°C", description: "Sleeping bag hangat untuk suhu ekstrim hingga -5°C. Material berkualitas dengan kompresi bag.", price_per_day: 40000, stock: 15, deposit: 200000, rating_avg: 0, total_reviews: 0, total_bookings: 0, is_active: true },
  { id: 6, category_id: 3, name: "Sleeping Bag Comfort", description: "Sleeping bag nyaman untuk suhu 10-20°C. Ringan dan mudah dibawa, cocok untuk camping biasa.", price_per_day: 30000, stock: 20, deposit: 150000, rating_avg: 0, total_reviews: 0, total_bookings: 0, is_active: true },
  { id: 7, category_id: 4, name: "Kompor Portable Gas", description: "Kompor gas portable dengan sistem piezo. Efisien dan aman untuk memasak outdoor.", price_per_day: 25000, stock: 18, deposit: 150000, rating_avg: 0, total_reviews: 0, total_bookings: 0, is_active: true },
  { id: 8, category_id: 4, name: "Nesting Set 4 Pcs", description: "Set peralatan masak lengkap 4 pieces. Ringan, anti lengket, termasuk panci dan wajan mini.", price_per_day: 20000, stock: 25, deposit: 100000, rating_avg: 0, total_reviews: 0, total_bookings: 0, is_active: true },
  { id: 9, category_id: 5, name: "Trekking Pole Adjustable", description: "Tongkat gunung adjustable dengan anti-shock system. Material aluminium ringan dan kuat.", price_per_day: 15000, stock: 30, deposit: 100000, rating_avg: 0, total_reviews: 0, total_bookings: 0, is_active: true },
  { id: 10, category_id: 5, name: "Headlamp LED 500 Lumens", description: "Headlamp LED super terang 500 lumens dengan 3 mode cahaya. Baterai tahan lama, waterproof IPX4.", price_per_day: 20000, stock: 22, deposit: 120000, rating_avg: 0, total_reviews: 0, total_bookings: 0, is_active: false },
  { id: 11, category_id: 1, name: "Tenda 6 Orang Family", description: "Tenda besar untuk keluarga dengan 2 kamar", price_per_day: 100000, stock: 5, deposit: 500000, rating_avg: 0, total_reviews: 0, total_bookings: 0, is_active: true },
  { id: 12, category_id: 1, name: "Tenda 6 Orang Family", description: "Tenda besar untuk keluarga dengan 2 kamar", price_per_day: 100000, stock: 5, deposit: 500000, rating_avg: 0, total_reviews: 0, total_bookings: 0, is_active: true },
];

export const SEED_IMAGES: EquipmentImage[] = [
  { id: 1, equipment_id: 1, image_url: "uploads/equipments/tent-4person.jpg", is_primary: true, sort_order: 1 },
  { id: 2, equipment_id: 2, image_url: "uploads/equipments/tent-ultralight.jpg", is_primary: true, sort_order: 1 },
  { id: 3, equipment_id: 3, image_url: "uploads/equipments/carrier-60l.jpg", is_primary: true, sort_order: 1 },
  { id: 4, equipment_id: 4, image_url: "uploads/equipments/carrier-80l.jpg", is_primary: true, sort_order: 1 },
  { id: 5, equipment_id: 5, image_url: "uploads/equipments/sleeping-bag-winter.jpg", is_primary: true, sort_order: 1 },
  { id: 6, equipment_id: 6, image_url: "uploads/equipments/sleeping-bag-comfort.jpg", is_primary: true, sort_order: 1 },
  { id: 7, equipment_id: 7, image_url: "uploads/equipments/kompor-gas.jpg", is_primary: true, sort_order: 1 },
  { id: 8, equipment_id: 8, image_url: "uploads/equipments/nesting-set.jpg", is_primary: true, sort_order: 1 },
  { id: 9, equipment_id: 9, image_url: "uploads/equipments/trekking-pole.jpg", is_primary: true, sort_order: 1 },
  { id: 10, equipment_id: 10, image_url: "uploads/equipments/headlamp.jpg", is_primary: true, sort_order: 1 },
  { id: 13, equipment_id: 12, image_url: "uploads/equipments/equip_6ae32b6b65fb39.64125313.png", is_primary: true, sort_order: 0 },
  { id: 14, equipment_id: 11, image_url: "uploads/equipments/equip_6ae4478fbb2a73.15843132.jpg", is_primary: true, sort_order: 0 },
];

export const SEED_REVIEWS: Review[] = [
  { id: 1, booking_id: 1, user_id: 2, equipment_id: 1, rating: 5, comment: "Barang sangat bagus!", created_at: "2026-10-08T08:13:33+00:00", user_name: "MESSI" },
];

/**
 * Foto referensi per alat, diunduh ke public/images dan dicek isinya.
 * Bucket equipment-images di Supabase masih kosong, jadi foto asli unit
 * belum ada. Foto-foto ini foto referensi kategori, BUKAN foto unit yang
 * disewakan, dan itu ditulis jelas di footer. Ganti dengan foto asli
 * begitu user mengunggah foto ke bucket.
 */
export const PHOTO_BY_EQUIPMENT: Record<number, string> = {
  1: "/images/tent-dalam.jpg",
  2: "/images/tenda-malam.jpg",
  3: "/images/carrier.jpg",
  4: "/images/pendaki-tebing.jpg",
  5: "/images/tent-dalam.jpg",
  6: "/images/api-unggun.jpg",
  7: "/images/api-unggun.jpg",
  8: "/images/tenda-keluarga.jpg",
  9: "/images/pendaki-jalur.jpg",
  10: "/images/tenda-malam.jpg",
  11: "/images/tenda-keluarga.jpg",
  12: "/images/hero.jpg",
};

export const PHOTO_BY_CATEGORY: Record<number, string> = {
  1: "/images/tenda-keluarga.jpg",
  2: "/images/carrier.jpg",
  3: "/images/tent-dalam.jpg",
  4: "/images/api-unggun.jpg",
  5: "/images/pendaki-jalur.jpg",
};

export function photoForEquipment(equipment: Equipment): string {
  return PHOTO_BY_EQUIPMENT[equipment.id] ?? PHOTO_BY_CATEGORY[equipment.category_id] ?? "/images/hero.jpg";
}
