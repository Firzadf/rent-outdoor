/**
 * Mark OutdoorRent: lingkaran hijau forest dengan siluet gunung putih
 * dan matahari oranye. Satu mark dipakai di favicon, header publik,
 * header akun, dan sidebar admin, supaya identitas konsisten.
 * Bentuk disederhanakan supaya terbaca di 16px.
 */
export function LogoMark({ size = 32, className }: { size?: number; className?: string }) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 64 64"
      role="img"
      aria-label="OutdoorRent"
      className={className}
    >
      <circle cx="32" cy="32" r="32" fill="#0f2a1a" />
      <circle cx="47" cy="17" r="5" fill="#f06a2e" />
      <path d="M8 48 L26 20 L35 33 L42 24 L56 48 Z" fill="#ffffff" />
    </svg>
  );
}
