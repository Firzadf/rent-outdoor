"use client";

import { useEffect, useRef, useState } from "react";

/**
 * Latar gunung 3D di hero (revisi 18 Nov 2026, modern-web-guidance
 * parallax-scroll-effects + motion): tiga punggung gunung SVG berlapis
 * dengan kedalaman berbeda, matahari ember, dan kabut yang bergerak
 * pelan. Lapisan luar mengatur parallax scroll (view-timeline hero,
 * offset beda per lapisan), SVG di dalamnya mengatur drift lambat;
 * pointer memiringkan seluruh adegan seperti Tilt kartu. Hanya
 * transform dan opacity, tanpa Three.js. Tenang dan redup supaya teks
 * tetap jelas. Tombol jeda memenuhi WCAG 2.2.2: animasi berjalan terus,
 * pengguna harus bisa mematikannya. Di reduced motion, lapisan tampil
 * statis (diatur CSS) dan tombol jeda disembunyikan.
 */
export function HeroDepth() {
  const ref = useRef<HTMLDivElement>(null);
  const [paused, setPaused] = useState(false);

  useEffect(() => {
    const layer = ref.current;
    const parent = layer?.parentElement;
    if (!layer || !parent) return;
    const layerEl = layer;
    const parentEl = parent;
    function onMove(e: PointerEvent) {
      if (e.pointerType !== "mouse") return;
      if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;
      const r = parentEl.getBoundingClientRect();
      const px = (e.clientX - r.left) / r.width - 0.5;
      const py = (e.clientY - r.top) / r.height - 0.5;
      layerEl.style.setProperty("--px", px.toFixed(3));
      layerEl.style.setProperty("--py", py.toFixed(3));
    }
    function onLeave() {
      layerEl.style.setProperty("--px", "0");
      layerEl.style.setProperty("--py", "0");
    }
    parentEl.addEventListener("pointermove", onMove);
    parentEl.addEventListener("pointerleave", onLeave);
    return () => {
      parentEl.removeEventListener("pointermove", onMove);
      parentEl.removeEventListener("pointerleave", onLeave);
    };
  }, []);

  return (
    <>
      <div ref={ref} className={`hero-depth${paused ? " paused" : ""}`} aria-hidden="true">
        <span className="sun" />
        <div className="ridge r-back">
          <svg viewBox="0 0 1200 260" preserveAspectRatio="none" aria-hidden="true">
            <path
              d="M0 210 L140 120 L260 190 L420 70 L560 180 L720 100 L880 200 L1040 90 L1200 190 L1200 260 L0 260 Z"
              fill="#1e6b3a"
            />
          </svg>
        </div>
        <div className="ridge r-mid">
          <svg viewBox="0 0 1200 300" preserveAspectRatio="none" aria-hidden="true">
            <path
              d="M0 240 L120 140 L300 230 L480 90 L640 210 L820 130 L980 240 L1120 160 L1200 220 L1200 300 L0 300 Z"
              fill="#16301f"
            />
          </svg>
        </div>
        <div className="fog">
          <svg viewBox="0 0 1200 90" preserveAspectRatio="none" aria-hidden="true">
            <ellipse cx="300" cy="45" rx="320" ry="34" fill="#faf7f1" />
            <ellipse cx="900" cy="50" rx="360" ry="30" fill="#faf7f1" />
          </svg>
        </div>
        <div className="ridge r-front">
          <svg viewBox="0 0 1200 340" preserveAspectRatio="none" aria-hidden="true">
            <path
              d="M0 280 L180 150 L360 260 L540 110 L760 250 L940 160 L1080 270 L1200 200 L1200 340 L0 340 Z"
              fill="#0f2a1a"
            />
          </svg>
        </div>
      </div>
      <button
        type="button"
        className="btn btn-ghost btn-small hero-motion-toggle"
        onClick={() => setPaused((p) => !p)}
      >
        {paused ? "Putar animasi" : "Jeda animasi"}
      </button>
    </>
  );
}
