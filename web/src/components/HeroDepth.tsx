"use client";

import { useEffect, useRef, useState } from "react";
import type * as THREE from "three";

/**
 * Latar gunung 3D di hero (revisi 18 Nov 2026): adegan gunung low-poly
 * SESUNGGUHNYA dengan Three.js, bukan lagi SVG CSS.
 *
 * Kenapa diganti: versi CSS sebelumnya tidak kelihatan. `.hero-depth`
 * menutupi seluruh hero dan punggung gunungnya duduk di `bottom: 0`,
 * tepat di belakang foto hero (`.hero-media` menutupinya penuh), jadi
 * yang tersisa hanya matahari oranye yang mengambang sendirian di kanan
 * atas. Di sini canvas dibatasi ke zona headline (`.hero-top`) saja,
 * jadi gunung duduk tepat di belakang headline dan jelas terlihat.
 *
 * Adegan: tiga lapis gunung low-poly (cone flat-shading) dengan jarak
 * berbeda, matahari ember dengan halo, kabut yang bergerak pelan,
 * dan lantai lembah. Kamera bergerak pelan (drift), parallax mengikuti
 * pointer dan scroll. Hanya WebGL canvas + transform, tanpa Three.js
 * di server (dynamic import di useEffect). Tombol jeda memenuhi
 * WCAG 2.2.2. Di reduced motion hanya satu frame statis yang dirender.
 * Di layar kecil gunung lebih sedikit dan pixel ratio dibatasi.
 *
 * Nuansa editorial petualangan (arahan user, referensi Red Bull):
 * halaman Red Bull yang diminta user tidak bisa dibuka dari sini
 * (domain diblokir kebijakan), jadi yang diterapkan adalah pola umum
 * editorial petualangan: foto imersif memenuhi layar, tipografi
 * display besar dan berani, dan adegan alam yang terasa nyata, bukan
 * hiasan samar. Tidak ada konten Red Bull yang disalin.
 */
export function HeroDepth() {
  const ref = useRef<HTMLDivElement>(null);
  const [paused, setPaused] = useState(false);
  const pausedRef = useRef(false);
  const apiRef = useRef<{ start: () => void; stop: () => void } | null>(null);

  useEffect(() => {
    pausedRef.current = paused;
    if (paused) apiRef.current?.stop();
    else apiRef.current?.start();
  }, [paused]);

  useEffect(() => {
    const container = ref.current;
    if (!container || typeof window === "undefined") return;
    const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    const small = container.clientWidth < 900;

    let cancelled = false;
    let renderer: THREE.WebGLRenderer | null = null;
    let raf = 0;
    let running = false;
    let disposed = false;
    const disposables: { dispose(): void }[] = [];
    const listeners: [EventTarget, string, EventListener, AddEventListenerOptions?][] = [];
    let resizeObserver: ResizeObserver | null = null;

    function on(
      target: EventTarget,
      type: string,
      fn: EventListener,
      opts?: AddEventListenerOptions,
    ) {
      target.addEventListener(type, fn, opts);
      listeners.push([target, type, fn, opts]);
    }

    // Acak deterministik supaya adegan stabil antar render.
    function mulberry32(seed: number) {
      return () => {
        seed |= 0;
        seed = (seed + 0x6d2b79f5) | 0;
        let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
        t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
        return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
      };
    }

    function makeGlowTexture(THREE: typeof import("three")) {
      const c = document.createElement("canvas");
      c.width = 128;
      c.height = 128;
      const ctx = c.getContext("2d");
      if (!ctx) return null;
      const g = ctx.createRadialGradient(64, 64, 0, 64, 64, 64);
      g.addColorStop(0, "rgba(240, 106, 46, 0.55)");
      g.addColorStop(0.45, "rgba(240, 106, 46, 0.22)");
      g.addColorStop(1, "rgba(240, 106, 46, 0)");
      ctx.fillStyle = g;
      ctx.fillRect(0, 0, 128, 128);
      const tex = new THREE.CanvasTexture(c);
      disposables.push(tex);
      return tex;
    }

    void import("three").then((THREE) => {
      if (cancelled || !container) return;

      const width = container.clientWidth || 1200;
      const height = container.clientHeight || 480;
      renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true });
      renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, small ? 1.5 : 2));
      renderer.setSize(width, height, false);
      renderer.domElement.setAttribute("aria-hidden", "true");
      container.appendChild(renderer.domElement);

      const scene = new THREE.Scene();
      scene.fog = new THREE.Fog(0xfaf7f1, 22, 46);

      const camera = new THREE.PerspectiveCamera(42, width / height, 0.1, 120);
      camera.position.set(0, 2.6, 15);

      scene.add(new THREE.HemisphereLight(0xfaf7f1, 0x16301f, 1.0));
      const sunLight = new THREE.DirectionalLight(0xffe0b3, 1.4);
      sunLight.position.set(9, 10, 6);
      scene.add(sunLight);

      const world = new THREE.Group();
      scene.add(world);

      // Lantai lembah: bidang gelap di bawah, memudar ke kabut.
      const ground = new THREE.Mesh(
        new THREE.PlaneGeometry(90, 34),
        new THREE.MeshStandardMaterial({ color: 0x0f2a1a, roughness: 1, metalness: 0 }),
      );
      ground.rotation.x = -Math.PI / 2;
      ground.position.set(0, -1.4, -4);
      world.add(ground);
      disposables.push(ground.geometry, ground.material as THREE.Material);

      // Tiga lapis gunung low-poly: kerucut flat-shading yang tumpang
      // tindih membentuk punggung pegunungan. Lapis jauh lebih terang
      // (kabut), lapis dekat paling gelap dan besar.
      const rand = mulberry32(20261118);
      const layers = [
        { z: -16, color: 0x2a7a45, count: small ? 5 : 8, hMin: 4.5, hMax: 7.5, rMin: 3.2, rMax: 5 },
        { z: -11, color: 0x16301f, count: small ? 4 : 7, hMin: 5.5, hMax: 9, rMin: 3.8, rMax: 5.5 },
        { z: -6, color: 0x0f2a1a, count: small ? 3 : 6, hMin: 7, hMax: 11, rMin: 4.5, rMax: 6.5 },
      ];
      for (const layer of layers) {
        for (let i = 0; i < layer.count; i++) {
          const h = layer.hMin + rand() * (layer.hMax - layer.hMin);
          const r = layer.rMin + rand() * (layer.rMax - layer.rMin);
          const cone = new THREE.Mesh(
            new THREE.ConeGeometry(r, h, 5),
            new THREE.MeshStandardMaterial({
              color: layer.color,
              flatShading: true,
              roughness: 1,
              metalness: 0,
            }),
          );
          const span = 36;
          cone.position.set(
            -span / 2 + (i / Math.max(1, layer.count - 1)) * span + (rand() - 0.5) * 3,
            h / 2 - 1.4,
            layer.z + (rand() - 0.5) * 1.5,
          );
          cone.rotation.y = rand() * Math.PI;
          world.add(cone);
          disposables.push(cone.geometry, cone.material as THREE.Material);
        }
      }

      // Matahari ember dengan halo, bagian dari adegan, bukan bulatan
      // yang mengambang sendirian.
      const sun = new THREE.Mesh(
        new THREE.CircleGeometry(1.6, 40),
        new THREE.MeshBasicMaterial({ color: 0xf06a2e }),
      );
      sun.position.set(9.5, 6.4, -14);
      world.add(sun);
      disposables.push(sun.geometry, sun.material as THREE.Material);
      const glowTex = makeGlowTexture(THREE);
      if (glowTex) {
        const glow = new THREE.Sprite(
          new THREE.SpriteMaterial({ map: glowTex, transparent: true, opacity: 0.6, depthWrite: false }),
        );
        glow.scale.set(9, 9, 1);
        glow.position.set(9.5, 6.4, -14.5);
        world.add(glow);
        disposables.push(glow.material as THREE.Material);
      }

      // Awan datar yang bergerak pelan.
      const clouds: THREE.Group[] = [];
      const cloudSpeeds: number[] = [];
      for (let i = 0; i < (small ? 2 : 4); i++) {
        const cloud = new THREE.Group();
        const puffs = 2 + Math.floor(rand() * 2);
        for (let p = 0; p < puffs; p++) {
          const s = new THREE.Mesh(
            new THREE.SphereGeometry(1 + rand() * 0.9, 12, 8),
            new THREE.MeshBasicMaterial({ color: 0xffffff, transparent: true, opacity: 0.5 }),
          );
          s.scale.y = 0.26;
          s.position.set(p * 1.6 - puffs * 0.8, (rand() - 0.5) * 0.4, 0);
          cloud.add(s);
          disposables.push(s.geometry, s.material as THREE.Material);
        }
        cloud.position.set(-12 + rand() * 24, 4.6 + rand() * 2, -9 - rand() * 4);
        world.add(cloud);
        clouds.push(cloud);
        cloudSpeeds.push(0.12 + rand() * 0.2);
      }

      const heroEl = container.closest(".hero") as HTMLElement | null;
      const pointer = { x: 0, y: 0, tx: 0, ty: 0 };
      const parent = container.parentElement;
      if (parent && !small) {
        on(parent, "pointermove", ((e: PointerEvent) => {
          if (e.pointerType !== "mouse") return;
          const r = parent.getBoundingClientRect();
          pointer.tx = (e.clientX - r.left) / r.width - 0.5;
          pointer.ty = (e.clientY - r.top) / r.height - 0.5;
        }) as EventListener);
        on(parent, "pointerleave", (() => {
          pointer.tx = 0;
          pointer.ty = 0;
        }) as EventListener);
      }

      const clock = new THREE.Clock();
      let last = 0;

      function renderFrame() {
        if (!renderer) return;
        const t = clock.getElapsedTime();
        // Drift kamera yang tenang.
        pointer.x += (pointer.tx - pointer.x) * 0.04;
        pointer.y += (pointer.ty - pointer.y) * 0.04;
        camera.position.x = Math.sin(t * 0.06) * 0.6 + pointer.x * 1.4;
        camera.position.y = 2.6 + Math.sin(t * 0.045) * 0.16 - pointer.y * 0.5;
        // Parallax scroll: gunung turun perlahan saat hero keluar layar.
        let progress = 0;
        if (heroEl) {
          const rect = heroEl.getBoundingClientRect();
          progress = Math.min(1, Math.max(0, -rect.top / Math.max(1, rect.height)));
        }
        world.position.y = -progress * 1.6;
        camera.lookAt(0, 1.6, -8);
        // Awan bergerak, matahari naik turun halus.
        const dt = Math.min(0.05, t - last || 0.016);
        last = t;
        clouds.forEach((cloud, i) => {
          cloud.position.x += cloudSpeeds[i] * dt;
          if (cloud.position.x > 17) cloud.position.x = -17;
        });
        sun.position.y = 6.4 + Math.sin(t * 0.12) * 0.12;
        renderer.render(scene, camera);
      }

      function loop() {
        if (!running || disposed) return;
        renderFrame();
        raf = requestAnimationFrame(loop);
      }

      apiRef.current = {
        start() {
          if (running || disposed || !renderer) return;
          running = true;
          clock.getElapsedTime();
          last = 0;
          raf = requestAnimationFrame(loop);
        },
        stop() {
          running = false;
          cancelAnimationFrame(raf);
        },
      };

      function resize() {
        if (!renderer || !container) return;
        const w = container.clientWidth || 1200;
        const h = container.clientHeight || 480;
        renderer.setSize(w, h, false);
        camera.aspect = w / h;
        camera.updateProjectionMatrix();
      }
      if (typeof ResizeObserver !== "undefined") {
        resizeObserver = new ResizeObserver(resize);
        resizeObserver.observe(container);
      }
      on(window, "resize", resize as EventListener);
      on(document, "visibilitychange", (() => {
        if (document.hidden) apiRef.current?.stop();
        else if (!pausedRef.current && !reduced) apiRef.current?.start();
      }) as EventListener);

      // Frame pertama selalu dirender, supaya adegan kelihatan walau
      // animasi dimatikan (reduced motion atau jeda).
      renderFrame();
      if (!reduced && !pausedRef.current) apiRef.current.start();
    });

    return () => {
      cancelled = true;
      disposed = true;
      apiRef.current?.stop();
      apiRef.current = null;
      cancelAnimationFrame(raf);
      for (const [target, type, fn, opts] of listeners) {
        target.removeEventListener(type, fn, opts);
      }
      resizeObserver?.disconnect();
      for (const d of disposables) d.dispose();
      if (renderer) {
        renderer.dispose();
        renderer.domElement.remove();
        renderer = null;
      }
    };
  }, []);

  return (
    <>
      <div ref={ref} className={`hero-depth${paused ? " paused" : ""}`} aria-hidden="true">
        <div className="hero-depth-haze" />
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
