import type { CSSProperties } from "react";
import Image from "next/image";
import Link from "next/link";
import { fetchCatalog } from "@/lib/data";
import { EquipmentCard } from "@/components/EquipmentCard";
import { RentalDates } from "@/components/RentalDates";
import { Tilt } from "@/components/Tilt";
import { PHOTO_BY_CATEGORY } from "@/lib/seed";

const HERO_WORDS = ["Alat", "outdoor", "siap", "jalan,", "tanpa", "harus", "beli."];

export default async function HomePage() {
  const { categories, equipments, images, isDemo } = await fetchCatalog();
  const active = equipments.filter((e) => e.is_active);
  const popular = [...active]
    .sort((a, b) => Number(b.total_bookings) - Number(a.total_bookings) || Number(b.rating_avg) - Number(a.rating_avg))
    .slice(0, 6);
  const catCount = (id: number) => active.filter((e) => e.category_id === id).length;

  return (
    <>
      {isDemo && (
        <div className="demo-banner">
          <div className="wrap">
            Mode contoh: Supabase belum terhubung, data yang tampil adalah data seed.
            Isi <code>NEXT_PUBLIC_SUPABASE_URL</code> dan <code>NEXT_PUBLIC_SUPABASE_ANON_KEY</code> di{" "}
            <code>.env.local</code> untuk memakai data live.
          </div>
        </div>
      )}

      <section className="hero">
        <div className="hero-copy">
          <h1>
            {HERO_WORDS.map((word, i) => (
              <span key={i} className="hero-word" style={{ "--i": i } as CSSProperties}>
                {word}{" "}
              </span>
            ))}
          </h1>
          <p>
            Sewa tenda, carrier, sleeping bag, dan peralatan hiking per hari.
            Ambil, pakai, kembalikan. Deposit kembali utuh bila alat kembali baik.
          </p>
          <RentalDates />
          <div className="hero-cta">
            <Link href="/katalog" className="btn btn-primary">Lihat Semua Alat</Link>
            <Link href="/daftar" className="btn btn-ghost">Buat Akun</Link>
          </div>
        </div>
        <div className="hero-media">
          <Image
            src="/images/hero.jpg"
            alt="Tenda di pegunungan saat matahari terbit"
            fill
            priority
            sizes="(max-width: 900px) 100vw, 50vw"
          />
          <div className="hero-chips" aria-hidden="true">
            <span className="hero-chip">{active.length} alat aktif · {categories.length} kategori</span>
            <span className="hero-chip">Deposit kembali utuh</span>
          </div>
        </div>
      </section>

      <section className="section reveal">
        <div className="wrap">
          <div className="section-head">
            <h2>Semua alat, lima kategori.</h2>
            <p>
              {active.length} alat aktif dari {equipments.length} alat di katalog.
              Pilih kategori, bandingkan harga per hari dan deposit, lalu sewa.
            </p>
          </div>
          <div className="cat-grid">
            {categories.map((cat) => (
              <Link key={cat.id} href={`/katalog?kategori=${cat.id}`} className="cat-cell">
                <Image
                  src={PHOTO_BY_CATEGORY[cat.id] ?? "/images/hero.jpg"}
                  alt={cat.name}
                  fill
                  sizes="(max-width: 900px) 50vw, 20vw"
                />
                <span>
                  {cat.name} · {catCount(cat.id)} alat
                </span>
              </Link>
            ))}
          </div>
        </div>
      </section>

      <section className="section section-alt reveal">
        <div className="wrap">
          <div className="section-head">
            <h2>Paling sering disewa.</h2>
            <p>Diurutkan dari jumlah booking terbanyak di data yang ada.</p>
          </div>
          <div className="eq-grid">
            {popular.map((eq) => (
              <Tilt key={eq.id}>
                <EquipmentCard
                  equipment={eq}
                  images={images}
                  categoryName={categories.find((c) => c.id === eq.category_id)?.name}
                />
              </Tilt>
            ))}
          </div>
        </div>
      </section>

      <section className="section reveal">
        <div className="wrap">
          <div className="section-head">
            <h2>Cara sewa.</h2>
            <p>Tiga langkah, tanpa telepon dan tanpa antre.</p>
          </div>
          <div className="steps">
            <div className="step">
              <h3>Pilih tanggal dan alat</h3>
              <p>
                Tentukan tanggal ambil dan kembali, lalu pilih alat dan jumlahnya.
                Harga sewa dan deposit dihitung langsung per hari.
              </p>
            </div>
            <div className="step">
              <h3>Bayar dan unggah bukti</h3>
              <p>
                Buat pesanan, lalu transfer dan unggah bukti bayar di halaman
                Pesanan Saya. Admin memverifikasi sebelum alat disiapkan.
              </p>
            </div>
            <div className="step">
              <h3>Ambil dan kembalikan</h3>
              <p>
                Ambil alat pada tanggal yang dipilih, pakai, lalu kembalikan tepat
                waktu. Deposit kembali setelah alat diperiksa.
              </p>
            </div>
          </div>
        </div>
      </section>
    </>
  );
}
