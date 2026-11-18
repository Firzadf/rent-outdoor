export type Category = {
  id: number;
  name: string;
  description: string | null;
  icon: string | null;
};

export type Equipment = {
  id: number;
  category_id: number;
  name: string;
  description: string | null;
  price_per_day: number;
  stock: number;
  deposit: number;
  rating_avg: number;
  total_reviews: number;
  total_bookings: number;
  is_active: boolean;
};

export type EquipmentImage = {
  id: number;
  equipment_id: number;
  image_url: string;
  is_primary: boolean;
  sort_order: number;
};

export type AppUser = {
  id: number;
  email: string;
  name: string;
  phone: string | null;
  address: string | null;
  role: "admin" | "customer" | "moderator";
  auth_user_id: string | null;
};

export type BookingItem = {
  id: number;
  booking_id: number;
  equipment_id: number;
  quantity: number;
  price_per_day: number;
  subtotal: number;
  equipment?: Equipment;
};

export type Booking = {
  id: number;
  user_id: number;
  booking_code: string;
  pickup_date: string;
  return_date: string;
  actual_return_date: string | null;
  total_days: number;
  subtotal: number;
  deposit_total: number;
  late_fee: number;
  damage_fee: number;
  deposit_refund: number;
  grand_total: number;
  status:
    | "pending_payment"
    | "pending_verification"
    | "confirmed"
    | "in_use"
    | "completed"
    | "cancelled"
    | "rejected";
  notes: string | null;
  cancellation_reason: string | null;
  return_condition: string | null;
  return_notes: string | null;
  created_at: string;
  items?: BookingItem[];
};

export type Payment = {
  id: number;
  booking_id: number;
  amount: number;
  payment_proof: string | null;
  bank_name: string | null;
  account_name: string | null;
  account_number: string | null;
  status: "pending" | "approved" | "rejected";
  payment_date: string | null;
  rejection_reason: string | null;
  created_at: string;
  booking?: Pick<Booking, "booking_code" | "status">;
};

export type Review = {
  id: number;
  booking_id: number;
  user_id: number;
  equipment_id: number;
  rating: number;
  comment: string | null;
  created_at: string;
  user_name?: string;
};

export const BOOKING_STATUS_LABEL: Record<Booking["status"], string> = {
  pending_payment: "Menunggu Pembayaran",
  pending_verification: "Menunggu Verifikasi",
  confirmed: "Dikonfirmasi",
  in_use: "Sedang Dipakai",
  completed: "Selesai",
  cancelled: "Dibatalkan",
  rejected: "Ditolak",
};

export const PAYMENT_STATUS_LABEL: Record<Payment["status"], string> = {
  pending: "Menunggu Verifikasi",
  approved: "Disetujui",
  rejected: "Ditolak",
};
