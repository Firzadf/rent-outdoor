import Link from "next/link";

export function SiteFooter() {
  return (
    <footer className="site-footer">
      <div className="wrap footer-inner">
        <div>
          <p className="footer-wordmark">OutdoorRent</p>
          <p className="footer-note">
            Sewa alat outdoor untuk camping dan pendakian. Harga per hari, deposit
            dikembalikan setelah alat kembali dalam kondisi baik.
          </p>
        </div>
        <nav aria-label="Tautan footer">
          <Link href="/katalog">Katalog</Link>
          <Link href="/pesanan">Pesanan Saya</Link>
          <Link href="/masuk">Masuk</Link>
          <Link href="/daftar">Daftar</Link>
        </nav>
      </div>
      <div className="wrap footer-credit">
        <p>
          Foto di halaman ini adalah foto referensi dari Unsplash (lisensi Unsplash,
          gratis dipakai), bukan foto unit yang disewakan. Foto asli alat akan
          menggantikan foto referensi begitu diunggah ke bucket equipment-images.
        </p>
        <p>OutdoorRent, proyek tugas kuliah Sistem Informasi, Universitas Bina Sarana Informatika.</p>
      </div>
    </footer>
  );
}
