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
    router.push("/pesanan");
  }

  return (
    <div className="wrap narrow">
      <h1>Masuk.</h1>
      <p>
        Akun lama template PHP tidak bisa dipakai di sini, karena password lamanya
        tersimpan sebagai hash bcrypt yang tidak dikenal Supabase Auth. Daftar akun baru.
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
