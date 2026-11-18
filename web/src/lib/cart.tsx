"use client";

import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from "react";
import { defaultRentalDates } from "./format";
import type { Equipment } from "./types";

export type CartItem = { equipmentId: number; qty: number };

type CartState = {
  items: CartItem[];
  startDate: string;
  endDate: string;
  addItem: (equipmentId: number, qty?: number) => void;
  removeItem: (equipmentId: number) => void;
  setQty: (equipmentId: number, qty: number) => void;
  setDates: (start: string, end: string) => void;
  clear: () => void;
  count: number;
};

const CartContext = createContext<CartState | null>(null);

const STORAGE_KEY = "outdoorrent-cart-v1";

export function CartProvider({ children }: { children: ReactNode }) {
  const [items, setItems] = useState<CartItem[]>([]);
  const [dates, setDatesState] = useState(defaultRentalDates);
  const [loaded, setLoaded] = useState(false);

  useEffect(() => {
    try {
      const raw = localStorage.getItem(STORAGE_KEY);
      if (raw) {
        const parsed = JSON.parse(raw) as { items?: CartItem[]; startDate?: string; endDate?: string };
        if (Array.isArray(parsed.items)) setItems(parsed.items);
        if (parsed.startDate && parsed.endDate) setDatesState({ start: parsed.startDate, end: parsed.endDate });
      }
    } catch {
      // abaikan keranjang rusak
    }
    setLoaded(true);
  }, []);

  useEffect(() => {
    if (!loaded) return;
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify({ items, startDate: dates.start, endDate: dates.end }));
    } catch {
      // penyimpanan penuh, abaikan
    }
  }, [items, dates, loaded]);

  const addItem = useCallback((equipmentId: number, qty = 1) => {
    setItems((prev) => {
      const found = prev.find((i) => i.equipmentId === equipmentId);
      if (found) {
        return prev.map((i) => (i.equipmentId === equipmentId ? { ...i, qty: i.qty + qty } : i));
      }
      return [...prev, { equipmentId, qty }];
    });
  }, []);

  const removeItem = useCallback((equipmentId: number) => {
    setItems((prev) => prev.filter((i) => i.equipmentId !== equipmentId));
  }, []);

  const setQty = useCallback((equipmentId: number, qty: number) => {
    setItems((prev) =>
      qty <= 0
        ? prev.filter((i) => i.equipmentId !== equipmentId)
        : prev.map((i) => (i.equipmentId === equipmentId ? { ...i, qty } : i)),
    );
  }, []);

  const setDates = useCallback((start: string, end: string) => {
    setDatesState({ start, end });
  }, []);

  const clear = useCallback(() => setItems([]), []);

  const value = useMemo<CartState>(
    () => ({
      items,
      startDate: dates.start,
      endDate: dates.end,
      addItem,
      removeItem,
      setQty,
      setDates,
      clear,
      count: items.reduce((n, i) => n + i.qty, 0),
    }),
    [items, dates, addItem, removeItem, setQty, setDates, clear],
  );

  return <CartContext.Provider value={value}>{children}</CartContext.Provider>;
}

export function useCart(): CartState {
  const ctx = useContext(CartContext);
  if (!ctx) throw new Error("useCart harus dipakai di dalam CartProvider");
  return ctx;
}

/** Hitung rincian sewa dari keranjang dan daftar alat. */
export function cartSummary(items: CartItem[], equipments: Equipment[], days: number) {
  const lines = items
    .map((item) => {
      const eq = equipments.find((e) => e.id === item.equipmentId);
      if (!eq) return null;
      return {
        equipment: eq,
        qty: item.qty,
        rent: eq.price_per_day * item.qty * days,
        deposit: eq.deposit * item.qty,
      };
    })
    .filter((l): l is NonNullable<typeof l> => l !== null);
  const subtotal = lines.reduce((n, l) => n + l.rent, 0);
  const depositTotal = lines.reduce((n, l) => n + l.deposit, 0);
  return { lines, subtotal, depositTotal, grandTotal: subtotal + depositTotal };
}
