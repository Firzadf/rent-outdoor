"use client";

import { useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useAuth } from "@/lib/auth";

export default function LoginPage() {
  const router = useRouter();
  const { signIn } = useAuth();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setError("");
    setBusy(true);
    const result = await signIn(email.trim(), password);
    setBusy(false);
    if (result.error) {
      setError(result.error);
      return;
    }
    // Tujuan setelah login: dashboard customer. Dashboard yang mengarahkan
    // staf ke /admin, jadi halaman ini tidak perlu menebak peran di sini.
    router.push("/dashboard");
  }

  return (
    <div className="wrap narrow">
      <h1>Masuk.</h1>
      <p>
        Masuk dengan akun yang terdaftar di Supabase Auth. Akun demo untuk
        proyek ini: admin@outdoorrent.com (admin) dan customer@test.com
        (customer). Akun baru bisa dibuat lewat halaman Daftar.
      </p>
      <form className="form" onSubmit={(e) => void submit(e)}>
        <div>
          <label htmlFor="email">Email</label>
          <input id="email" type="email" required value={email} onChange={(e) => setEmail(e.target.value)} />
        </div>
        <div>
          <label htmlFor="password">Password</label>
          <input
            id="password"
            type="password"
            required
            value={password}
            onChange={(e) => setPassword(e.target.value)}
          />
        </div>
        {error && <p className="form-error">{error}</p>}
        <button type="submit" className="btn btn-primary" disabled={busy}>
          {busy ? "Masuk." : "Masuk"}
        </button>
      </form>
      <p style={{ marginTop: 20 }}>
        Belum punya akun? <Link href="/daftar">Daftar</Link>
      </p>
    </div>
  );
}
