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
export const waMessage = o => 'Bonjour, je souhaite commander les produits suivants sur votre boutique en ligne :\n'
  + o.items.map(i => `- ${i.name} : ${i.qty} × ${fmt(i.price)}`).join('\n')
  + `\n\nRéférence : ${o.ref}.\n\nPouvez-vous confirmer la disponibilité et les modalités de livraison ?`;
