import { CustomerShell } from "@/components/CustomerShell";

/** Pengalaman customer setelah login: dashboard, pesanan, keranjang,
    checkout, dan profil di bawah sidebar customer, tanpa hero landing. */
export default function CustomerLayout({ children }: { children: React.ReactNode }) {
  return <CustomerShell>{children}</CustomerShell>;
}
