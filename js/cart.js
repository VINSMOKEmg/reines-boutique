import { sb } from './supabase.js';
// Panier : [{ id, qty, opt }]. Un même produit avec deux options différentes fait deux lignes.
// Copie de travail dans le navigateur ; connectée, il est aussi enregistré dans le compte (table carts)
// et la suit d'un appareil à l'autre. À la déconnexion, la copie locale est effacée (appareil partagé).
const K = 'reines_cart', OWNER = 'reines_cart_owner', DIRTY = 'reines_cart_dirty';
const ls = { get: k => { try { return localStorage.getItem(k); } catch { return null; } },
  set: (k, v) => { try { v == null ? localStorage.removeItem(k) : localStorage.setItem(k, v); } catch {} } };
const valid = c => (Array.isArray(c) ? c : []).filter(i => i && typeof i.id === 'string' && Number.isInteger(i.qty) && i.qty > 0);
export const get = () => { try { return valid(JSON.parse(ls.get(K) || '[]')); } catch { return []; } };
const write = c => { ls.set(K, JSON.stringify(c)); document.dispatchEvent(new Event('cart')); };
// DIRTY : modification locale pas encore enregistrée dans le compte (page quittée trop vite, hors ligne…).
const save = c => { write(c); ls.set(DIRTY, '1'); ready.then(push); };
export const key = i => i.id + '|' + (i.opt || '');

let uid = null, queue = Promise.resolve();
// Envois l'un après l'autre, toujours avec l'état local du moment : le dernier panier gagne.
function push() {
  if (!uid) return queue;
  return queue = queue.then(async () => {
    const c = ls.get(K) || '[]';
    const { error } = await sb.from('carts').upsert({ user_id: uid, items: JSON.parse(c), updated_at: new Date().toISOString() });
    if (!error && ls.get(K) === c) ls.set(DIRTY, null);
  }).catch(() => {});
}
// Même ligne dans les deux paniers : on garde la plus grande quantité (fusionner deux fois ne double rien).
const merge = (a, b) => {
  const m = new Map(a.map(i => [key(i), i]));
  b.forEach(i => { const j = m.get(key(i)); m.set(key(i), j ? { ...j, qty: Math.max(j.qty, i.qty) } : i); });
  return [...m.values()].slice(0, 100);
};
async function sync() {
  const { data: { session } } = await sb.auth.getSession();
  const owner = ls.get(OWNER);
  if (!session) { if (owner) { ls.set(OWNER, null); ls.set(DIRTY, null); write([]); } return; }
  const id = session.user.id;
  const { data, error } = await sb.from('carts').select('items').eq('user_id', id).maybeSingle();
  if (error) return; // hors ligne : panier local seulement, envoyé au prochain chargement (DIRTY)
  const server = valid(data?.items), local = get();
  const c = owner === id ? (ls.get(DIRTY) ? local : server) // même compte : le compte fait foi, sauf envoi en attente
    : owner ? server                                         // panier d'un autre compte resté sur l'appareil
    : merge(server, local);                                  // panier rempli avant de se connecter
  uid = id; ls.set(OWNER, id);
  if (JSON.stringify(c) !== JSON.stringify(local)) write(c);
  if (JSON.stringify(c) !== JSON.stringify(server)) { ls.set(DIRTY, '1'); push(); } else ls.set(DIRTY, null);
}
// À attendre avant d'afficher le contenu du panier.
export const ready = sync().catch(() => {});
export const count = () => get().reduce((a, i) => a + i.qty, 0);
export function add(id, q = 1, opt = '') { const c = get(), i = c.find(x => key(x) === key({ id, opt })); i ? i.qty = Math.min(99, i.qty + q) : c.push({ id, qty: q, opt }); save(c); }
export const setQty = (k, q) => save(get().map(i => key(i) === k ? { ...i, qty: Math.min(99, q) } : i).filter(i => i.qty > 0));
export const clear = () => save([]);
const fmt = n => Number(n).toLocaleString('fr-FR') + ' FCFA';
// Numéro au format international sans +, espaces ni tirets.
export const waLink = (num, text) => `https://wa.me/${String(num).replace(/\D/g, '')}?text=${encodeURIComponent(text)}`;
// Message de commande envoyé par la cliente à une vendeuse (*texte* = gras dans WhatsApp).
// o : commande renvoyée par place_order ; x : { name, lieu, note } saisis dans le panier (facultatifs).
export const waMessage = (o, x = {}) => [
  `Bonjour ${o.shop_name} 👋`,
  '',
  'Je souhaite commander sur *Les Reines de l’Entrepreneuriat* :',
  '',
  ...o.items.map(i => `▪️ ${i.qty} × ${i.name}${i.option ? ` (${i.option_label || 'Option'} : ${i.option})` : ''} — ${fmt(i.qty * i.price)}${i.regular ? ` (promo, au lieu de ${fmt(i.qty * i.regular)})` : ''}`),
  '',
  `*Total : ${fmt(o.total)}*`,
  `Référence : *${o.ref}*`,
  ...(x.lieu || x.note ? [''] : []),
  ...(x.lieu ? [`📍 Livraison : ${x.lieu}`] : []),
  ...(x.note ? [`📝 Précision : ${x.note}`] : []),
  '',
  x.lieu ? 'Pouvez-vous me confirmer la disponibilité, le délai et le prix de la livraison ?'
    : 'Pouvez-vous me confirmer la disponibilité et les modalités de livraison ?',
  'Merci beaucoup !',
  ...(x.name ? [x.name] : [])
].join('\n');
// Lieu de livraison mémorisé pour les prochaines commandes (sur cet appareil).
const LK = 'reines_lieu';
export const lieu = { get: () => { try { return localStorage.getItem(LK) || ''; } catch { return ''; } }, set: v => { try { localStorage.setItem(LK, v); } catch {} } };
