"use client";

import { useEffect, useState } from "react";
import { resolveProofUrl } from "@/lib/supabase";

/**
 * Tautan "Lihat bukti bayar" untuk bucket privat payment-proofs.
 * Mengambil signed URL (berlaku 1 jam) dan mengecek keberadaan file dulu.
 * Bila file tidak ada di Storage (misalnya baris seed lama yang hanya
 * mengisi payment_proof di database tanpa mengunggah file), tampilkan
 * pesan jujur, bukan tautan rusak dan bukan gambar pengganti.
 */
export function ProofLink({ path, label = "Lihat bukti bayar" }: { path: string; label?: string }) {
  const [state, setState] = useState<"loading" | "ready" | "missing">("loading");
  const [url, setUrl] = useState("");

  useEffect(() => {
    let alive = true;
    setState("loading");
    resolveProofUrl(path).then((r) => {
      if (!alive) return;
      if ("url" in r) {
        setUrl(r.url);
        setState("ready");
      } else {
        setState("missing");
      }
    });
    return () => {
      alive = false;
    };
  }, [path]);

  if (state === "loading") return <span className="proof-state">Memuat bukti.</span>;
  if (state === "missing") {
    return <span className="proof-missing">File bukti tidak ditemukan di Storage</span>;
  }
  return (
    <a href={url} target="_blank" rel="noreferrer">
      {label}
    </a>
  );
}
