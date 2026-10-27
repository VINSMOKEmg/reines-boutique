const K = 'reines_cart';
export const get = () => { try { return JSON.parse(localStorage.getItem(K) || '[]'); } catch { return []; } };
const save = c => { localStorage.setItem(K, JSON.stringify(c)); document.dispatchEvent(new Event('cart')); };
export const count = () => get().reduce((a, i) => a + i.qty, 0);
export function add(id, q = 1) { const c = get(), i = c.find(x => x.id === id); i ? i.qty = Math.min(99, i.qty + q) : c.push({ id, qty: q }); save(c); }
export const setQty = (id, q) => save(get().map(i => i.id === id ? { ...i, qty: Math.min(99, q) } : i).filter(i => i.qty > 0));
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
  ...o.items.map(i => `▪️ ${i.qty} × ${i.name} — ${fmt(i.qty * i.price)}`),
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
