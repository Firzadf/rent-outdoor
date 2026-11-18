"use client";

import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from "react";
import type { User } from "@supabase/supabase-js";
import { getBrowserClient } from "./supabase";
import type { AppUser } from "./types";

type AuthState = {
  user: User | null;
  appUser: AppUser | null;
  loading: boolean;
  /** true bila baris profil public.users tidak ditemukan atau gagal dibuat. */
  profileMissing: boolean;
  signIn: (email: string, password: string) => Promise<{ error?: string }>;
  signUp: (email: string, password: string, name: string) => Promise<{ error?: string }>;
  signOut: () => Promise<void>;
  refreshProfile: () => Promise<void>;
};

const AuthContext = createContext<AuthState | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [appUser, setAppUser] = useState<AppUser | null>(null);
  const [loading, setLoading] = useState(true);
  const [profileMissing, setProfileMissing] = useState(false);

  const loadProfile = useCallback(async (authUser: User | null) => {
    if (!authUser) {
      setAppUser(null);
      setProfileMissing(false);
      return;
    }
    const supabase = getBrowserClient();
    // Cari profil lewat auth_user_id dulu, lalu email sebagai cadangan.
    const byAuth = await supabase.from("users").select("*").eq("auth_user_id", authUser.id).maybeSingle();
    let row = byAuth.data as AppUser | null;
    if (!row) {
      const byEmail = await supabase.from("users").select("*").eq("email", authUser.email ?? "").maybeSingle();
      row = byEmail.data as AppUser | null;
      if (row && !row.auth_user_id) {
        await supabase.from("users").update({ auth_user_id: authUser.id }).eq("id", row.id);
        row = { ...row, auth_user_id: authUser.id };
      }
    }
    if (!row) {
      // Profil belum ada. Butuh policy users_insert_own dari migrasi
      // 20261118000001; tanpa itu insert gagal RLS dan profileMissing true.
      const inserted = await supabase
        .from("users")
        .insert({
          email: authUser.email ?? "",
          password: "supabase-auth",
          name: (authUser.user_metadata?.name as string | undefined) ?? authUser.email?.split("@")[0] ?? "Penyewa",
          role: "customer",
          auth_user_id: authUser.id,
        })
        .select()
        .single();
      if (!inserted.error && inserted.data) {
        row = inserted.data as AppUser;
      }
    }
    setAppUser(row);
    setProfileMissing(!row);
  }, []);

  useEffect(() => {
    const supabase = getBrowserClient();
    let alive = true;
    supabase.auth.getSession().then(async ({ data }) => {
      if (!alive) return;
      setUser(data.session?.user ?? null);
      await loadProfile(data.session?.user ?? null);
      setLoading(false);
    });
    const { data: listener } = supabase.auth.onAuthStateChange(async (_event, session) => {
      if (!alive) return;
      setUser(session?.user ?? null);
      await loadProfile(session?.user ?? null);
      setLoading(false);
    });
    return () => {
      alive = false;
      listener.subscription.unsubscribe();
    };
  }, [loadProfile]);

  const signIn = useCallback(async (email: string, password: string) => {
    const supabase = getBrowserClient();
    const { error } = await supabase.auth.signInWithPassword({ email, password });
    return error ? { error: error.message } : {};
  }, []);

  const signUp = useCallback(async (email: string, password: string, name: string) => {
    const supabase = getBrowserClient();
    const { error } = await supabase.auth.signUp({
      email,
      password,
      options: { data: { name } },
    });
    return error ? { error: error.message } : {};
  }, []);

  const signOut = useCallback(async () => {
    await getBrowserClient().auth.signOut();
    setUser(null);
    setAppUser(null);
  }, []);

  const refreshProfile = useCallback(async () => {
    await loadProfile(user);
  }, [loadProfile, user]);

  const value = useMemo<AuthState>(
    () => ({ user, appUser, loading, profileMissing, signIn, signUp, signOut, refreshProfile }),
    [user, appUser, loading, profileMissing, signIn, signUp, signOut, refreshProfile],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth(): AuthState {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error("useAuth harus dipakai di dalam AuthProvider");
  return ctx;
}
