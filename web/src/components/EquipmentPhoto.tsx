"use client";

import { useState } from "react";
import Image from "next/image";
import type { Equipment, EquipmentImage } from "@/lib/types";
import { equipmentPhotoUrl } from "@/lib/data";
import { photoForEquipment } from "@/lib/seed";

/** Foto alat: coba URL bucket dulu, jatuh ke foto referensi bila gagal muat. */
export function EquipmentPhoto({
  equipment,
  images,
  className,
  sizes,
}: {
  equipment: Equipment;
  images: EquipmentImage[];
  className?: string;
  sizes?: string;
}) {
  const primary = equipmentPhotoUrl(equipment, images);
  const fallback = photoForEquipment(equipment);
  const [src, setSrc] = useState(primary);
  return (
    <Image
      src={src}
      alt={equipment.name}
      fill
      sizes={sizes ?? "(max-width: 768px) 100vw, 33vw"}
      className={className}
      onError={() => {
        if (src !== fallback) setSrc(fallback);
      }}
    />
  );
}
