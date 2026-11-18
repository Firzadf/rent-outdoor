"use client";

import { useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useAuth } from "@/lib/auth";

export default function RegisterPage() {
  const router = useRouter();
  const { signUp } = useAuth();
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [note, setNote] = useState("");
  const [busy, setBusy] = useState(false);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setError("");
    setNote("");
    if (password.length < 6) {
      setError("Password minimal 6 karakter.");
      return;
    }
    setBusy(true);
    const result = await signUp(email.trim(), password, name.trim());
    setBusy(false);
    if (result.error) {
      setError(result.error);
      return;
    }
    setNote(
      "Akun dibuat. Bila konfirmasi email aktif di Supabase, cek email dan klik tautan konfirmasi sebelum login. Bila konfirmasi dimatikan, kamu langsung bisa masuk.",
    );
    setTimeout(() => router.push("/masuk"), 2500);
  }

  return (
    <div className="wrap narrow">
      <h1>Daftar akun baru.</h1>
      <p>
        Satu akun untuk checkout, pesanan, dan bukti bayar. Profil dibuat otomatis
        di tabel users setelah migrasi 20261118000001 dijalankan.
      </p>
      <form className="form" onSubmit={(e) => void submit(e)}>
        <div>
          <label htmlFor="nama">Nama lengkap</label>
          <input id="nama" required value={name} onChange={(e) => setName(e.target.value)} />
        </div>
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
          <span className="hint">Minimal 6 karakter.</span>
        </div>
        {error && <p className="form-error">{error}</p>}
        {note && <p className="form-ok">{note}</p>}
        <button type="submit" className="btn btn-primary" disabled={busy}>
          {busy ? "Membuat akun." : "Buat Akun"}
        </button>
      </form>
      <p style={{ marginTop: 20 }}>
        Sudah punya akun? <Link href="/masuk">Masuk</Link>
      </p>
    </div>
  );
}
