import { createClient, type SupabaseClient } from "@supabase/supabase-js";

export const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL ?? "";
export const SUPABASE_ANON_KEY = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ?? "";

export function isSupabaseConfigured(): boolean {
  return SUPABASE_URL.startsWith("https://") && SUPABASE_ANON_KEY.length > 20;
}

let browserClient: SupabaseClient | null = null;

/** Client untuk komponen client. Hanya memakai anon key dari env. */
export function getBrowserClient(): SupabaseClient {
  if (!browserClient) {
    browserClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
  }
  return browserClient;
}

/** Client untuk Server Component. Katalog dibaca publik, jadi tanpa sesi. */
export function getServerClient(): SupabaseClient {
  return createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

/** URL publik file di bucket storage. Hanya untuk bucket PUBLIK
    (equipment-images). Jangan dipakai untuk payment-proofs. */
export function publicStorageUrl(bucket: string, path: string): string {
  if (!SUPABASE_URL) return "";
  return `${SUPABASE_URL.replace(/\/$/, "")}/storage/v1/object/public/${bucket}/${path}`;
}

/**
 * URL bukti bayar di bucket PRIVAT payment-proofs.
 * Bucket ini public=false, jadi endpoint /object/public/ selalu membalas
 * 404 "Bucket not found". Yang benar: signed URL (berlaku 1 jam) yang
 * dibuat dengan sesi user yang sedang login, lewat createSignedUrl.
 *
 * File seed lama (uploads/payments/pay_*.png) kemungkinan memang tidak
 * pernah diunggah ke Storage, seed hanya mengisi baris database. Karena
 * itu keberadaan file dicek dulu lewat storage.list: bila tidak ada,
 * kembalikan { missing: true } supaya UI menampilkan pesan jujur
 * "File bukti tidak ditemukan di Storage", bukan link rusak.
 */
export type ProofUrlResult = { url: string } | { missing: true };

export async function resolveProofUrl(path: string): Promise<ProofUrlResult> {
  const clean = path.replace(/^\/+/, "");
  const slash = clean.lastIndexOf("/");
  const dir = slash > 0 ? clean.slice(0, slash) : "";
  const file = slash >= 0 ? clean.slice(slash + 1) : clean;
  const supabase = getBrowserClient();
  const { data: list, error: listError } = await supabase.storage
    .from("payment-proofs")
    .list(dir === "" ? undefined : dir, { search: file });
  if (listError || !list || !list.some((o) => o.name === file)) return { missing: true };
  const { data, error } = await supabase.storage
    .from("payment-proofs")
    .createSignedUrl(clean, 3600);
  if (error || !data?.signedUrl) return { missing: true };
  return { url: data.signedUrl };
}
