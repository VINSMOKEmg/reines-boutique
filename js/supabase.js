import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.45.4/+esm';
import { SUPABASE_URL, SUPABASE_ANON_KEY } from './config.js';
export const sb = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

export async function me() {
  const { data: { session } } = await sb.auth.getSession();
  if (!session) return null;
  const { data } = await sb.from('profiles').select('id,role,full_name,email').eq('id', session.user.id).single();
  return data;
}
// Confort d'affichage uniquement : la vraie protection, ce sont les politiques RLS.
export async function requireRole(roles) {
  const u = await me();
  if (!u || !roles.includes(u.role)) {
    location.replace('connexion.html?next=' + encodeURIComponent(location.pathname.split('/').pop() + location.search));
    return null;
  }
  return u;
}
