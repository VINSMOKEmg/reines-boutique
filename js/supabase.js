import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.45.4/+esm';
import { SUPABASE_URL, SUPABASE_ANON_KEY } from './config.js';
// Lu avant createClient, qui efface ensuite les jetons de l'URL : arrivée par un lien reçu par e-mail
// (« mot de passe oublié » = recovery ; confirmation d'inscription = login) ou lien expiré (error).
const H = new URLSearchParams(location.hash.slice(1));
export const AUTH_LINK = { recovery: H.get('type') === 'recovery', login: H.has('access_token') && H.get('type') !== 'recovery', error: H.get('error_code') || H.get('error') || '' };
export const HOME = { admin: 'admin.html', seller: 'dashboard.html', client: 'client.html' };
export const sb = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

export async function me() {
  const { data: { session } } = await sb.auth.getSession();
  if (!session) return null;
  const { data } = await sb.from('profiles').select('id,role,full_name,email').eq('id', session.user.id).single();
  return data;
}
// Confort d'affichage uniquement : la vraie protection, ce sont les politiques RLS.
// Non connectée -> page de connexion (puis retour ici) ; connectée avec un autre rôle -> son propre espace.
export async function requireRole(roles) {
  const u = await me();
  if (!u) { location.replace('connexion.html?next=' + encodeURIComponent(location.pathname.split('/').pop() + location.search)); return null; }
  if (!roles.includes(u.role)) { location.replace(HOME[u.role] || 'index.html'); return null; }
  return u;
}
