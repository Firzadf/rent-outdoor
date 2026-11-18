"use client";

import { useEffect, useRef } from "react";

/**
 * Latar 3D ambient di hero: lima bentuk tembus pandang melayang pelan
 * dengan kedalaman (translateZ dan rotasi kecil), plus kemiringan halus
 * mengikuti pointer mouse, satu sistem dengan Tilt kartu. Hanya
 * transform dan opacity, tanpa dependensi. Bentuknya redup dan tenang
 * supaya teks tetap jelas. Di layar kecil hanya dua bentuk yang tampil,
 * dan di reduced motion lapisan ini disembunyikan lewat CSS.
 */
const SHAPES = ["s1", "s2", "s3", "s4", "s5"];

export function HeroDepth() {
  const ref = useRef<HTMLDivElement>(null);

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
    <div ref={ref} className="hero-depth" aria-hidden="true">
      {SHAPES.map((s) => (
        <span key={s} className={`hero-shape ${s}`} />
      ))}
    </div>
  );
}
