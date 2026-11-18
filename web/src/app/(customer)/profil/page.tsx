"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { useAuth } from "@/lib/auth";
import { getBrowserClient } from "@/lib/supabase";

export default function ProfilePage() {
  const { user, appUser, loading, refreshProfile } = useAuth();
  const [name, setName] = useState("");
  const [phone, setPhone] = useState("");
  const [address, setAddress] = useState("");
  const [message, setMessage] = useState("");
  const [error, setError] = useState("");
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    if (appUser) {
      setName(appUser.name);
      setPhone(appUser.phone ?? "");
      setAddress(appUser.address ?? "");
    }
  }, [appUser]);

  if (loading) {
    return (
      <div className="wrap empty">
        <p>Memuat profil.</p>
      </div>
    );
  }

  if (!user) {
    return (
      <div className="wrap narrow">
        <h1>Login dulu untuk melihat profil.</h1>
        <Link href="/masuk" className="btn btn-primary">Masuk</Link>
      </div>
    );
  }

  async function save() {
    setError("");
    setMessage("");
    if (!appUser) {
      setError("Profil belum terbentuk. Coba muat ulang halaman ini.");
      return;
    }
    setSaving(true);
    const { error: err } = await getBrowserClient()
      .from("users")
      .update({ name: name.trim(), phone: phone.trim() || null, address: address.trim() || null })
      .eq("id", appUser.id);
    setSaving(false);
    if (err) setError(err.message);
    else {
      setMessage("Profil disimpan.");
      await refreshProfile();
    }
  }

  return (
    <div className="wrap narrow">
      <h1>Profil.</h1>
      <p>
        {user.email} · Peran:{" "}
        {appUser?.role === "admin" ? "Admin" : appUser?.role === "moderator" ? "Moderator" : "Customer"}
      </p>
      {!appUser && (
        <p className="form-error">
          Profil belum terbentuk. Coba muat ulang halaman ini.
        </p>
      )}
      <div className="form">
        <div>
          <label htmlFor="nama">Nama</label>
          <input id="nama" value={name} onChange={(e) => setName(e.target.value)} />
        </div>
        <div>
          <label htmlFor="telp">Telepon</label>
          <input id="telp" value={phone} onChange={(e) => setPhone(e.target.value)} />
        </div>
        <div>
          <label htmlFor="alamat">Alamat</label>
          <textarea id="alamat" rows={3} value={address} onChange={(e) => setAddress(e.target.value)} />
        </div>
        {error && <p className="form-error">{error}</p>}
        {message && <p className="form-ok">{message}</p>}
        <button type="button" className="btn btn-primary" disabled={saving} onClick={() => void save()}>
          {saving ? "Menyimpan." : "Simpan Profil"}
        </button>
      </div>
    </div>
  );
}
