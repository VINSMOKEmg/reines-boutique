import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.45.4/+esm';
import { SUPABASE_URL, SUPABASE_ANON_KEY } from './config.js';
// Lu avant createClient, qui efface ensuite les jetons de l'URL : arrivée par un lien reçu par e-mail
// (« mot de passe oublié » = recovery ; confirmation d'inscription = login) ou lien expiré (error).
const H = new URLSearchParams(location.hash.slice(1));
export const AUTH_LINK = { recovery: H.get('type') === 'recovery', login: H.has('access_token') && H.get('type') !== 'recovery', error: H.get('error_code') || H.get('error') || '' };
export const HOME = { admin: 'admin/index.html', seller: 'vendeuse/dashboard.html', client: 'compte/client.html' };
export const sb = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
// Racine du site (dossier parent de js/), quel que soit le dossier de la page affichée.
export const ROOT = new URL('../', import.meta.url).href;
// Chemin de la page courante depuis la racine, ex. « vendeuse/dashboard.html?id=3 ».
export const here = () => location.href.slice(ROOT.length).split('#')[0];
// Lien interne sûr pour ?next= : chemin relatif à la racine, sans « // » ni protocole.
export const safeNext = p => /^[a-z][a-z0-9\-]*(\/[a-z0-9\-]*)?(\.html)?(\?[^#]*)?$/.test(p || '') ? p : null;

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
  if (!u) { location.replace('compte/connexion.html?next=' + encodeURIComponent(here())); return null; }
  if (!roles.includes(u.role)) { location.replace(HOME[u.role] || 'index.html'); return null; }
  return u;
}
