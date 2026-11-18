"use client";

import { useRef } from "react";
import type { ReactNode } from "react";

/**
 * Tilt 3D berbasis pointer: kartu mengikuti posisi kursor dengan rotateX
 * dan rotateY kecil. Hanya aktif untuk pointer mouse dan bila pengguna
 * tidak minta gerakan dikurangi. Di layar sentuh dan reduced motion,
 * komponen ini tidak mengubah apa pun dan konten tetap tampil normal.
 */
export function Tilt({
  children,
  max = 6,
}: {
  children: ReactNode;
  max?: number;
}) {
  const ref = useRef<HTMLDivElement>(null);

  function onMove(e: React.PointerEvent) {
    const el = ref.current;
    if (!el || e.pointerType !== "mouse") return;
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;
    const r = el.getBoundingClientRect();
    const px = (e.clientX - r.left) / r.width - 0.5;
    const py = (e.clientY - r.top) / r.height - 0.5;
    el.style.setProperty("--rx", `${(-py * max).toFixed(2)}deg`);
    el.style.setProperty("--ry", `${(px * max).toFixed(2)}deg`);
  }

  function onLeave() {
    const el = ref.current;
    if (!el) return;
    el.style.setProperty("--rx", "0deg");
    el.style.setProperty("--ry", "0deg");
  }

  return (
    <div ref={ref} className="tilt" onPointerMove={onMove} onPointerLeave={onLeave}>
      {children}
    </div>
  );
}
