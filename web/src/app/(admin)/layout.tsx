import { Suspense } from "react";
import { AdminShell } from "@/components/AdminShell";

/** Pengalaman admin/moderator: sidebar sendiri, tanpa header landing. */
export default function AdminLayout({ children }: { children: React.ReactNode }) {
  return (
    <Suspense>
      <AdminShell>{children}</AdminShell>
    </Suspense>
  );
}
