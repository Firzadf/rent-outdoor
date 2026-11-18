"use client";

import { useCallback, useEffect, useState } from "react";
import { LogoMark } from "./LogoMark";

const SEEN_KEY = "outdoorrent-intro-seen";

/**
 * Layar loading 3D saat website pertama dibuka: mark logo berputar
 * masuk dalam 3D, huruf wordmark merangkai satu per satu, lalu layar
 * memudar ke landing. Hanya sekali per sesi tab (sessionStorage),
 * maksimal sekitar 1,6 detik, dan bisa dilewati dengan klik atau tap.
 * Tanpa animasi sama sekali bila pengguna mengatur reduced motion.
 */
export function IntroLoader() {
  const [show, setShow] = useState(() => {
    if (typeof window === "undefined") return true;
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return false;
    return !window.sessionStorage.getItem(SEEN_KEY);
  });
  const [leaving, setLeaving] = useState(false);

  const dismiss = useCallback(() => {
    setLeaving(true);
    window.setTimeout(() => {
      window.sessionStorage.setItem(SEEN_KEY, "1");
      setShow(false);
    }, 320);
  }, []);

  useEffect(() => {
    if (!show) return;
    const t = window.setTimeout(dismiss, 1300);
    return () => window.clearTimeout(t);
  }, [show, dismiss]);

  if (!show) return null;

  const word = "OutdoorRent";
  return (
    <div
      className={`intro-loader${leaving ? " leaving" : ""}`}
      role="presentation"
      aria-hidden="true"
      onClick={dismiss}
    >
      <div className="intro-mark">
        <LogoMark size={72} />
      </div>
      <p className="intro-word">
        {word.split("").map((ch, i) => (
          <span
            key={i}
            className={`intro-letter${i >= 7 ? " ember" : ""}`}
            style={{ animationDelay: `${i * 45}ms` }}
          >
            {ch}
          </span>
        ))}
      </p>
      <p className="intro-tag">Sewa alat outdoor, tanpa harus beli.</p>
      <p className="intro-hint">Ketuk di mana saja untuk masuk.</p>
    </div>
  );
}
